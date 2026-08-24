"""Kala — real-time voice agent. A WebSocket relay between the Flutter app and the
Gemini Live API (native-audio, us-central1). The phone streams mic PCM (16 kHz) up
and plays Kala's PCM (24 kHz) back down. Kala speaks Hindi, and can call backend
tools mid-conversation (orders, earnings, products) scoped to the signed-in
artisan — so it's an agent, not just a chatbot.

Topology (backend proxy): phone <-WS-> this relay <-Live-> Gemini. Tools run here
with the artisan's own DB session, so no data or credentials leave the server.
"""
import asyncio
import json
import logging

from fastapi import APIRouter, WebSocket, WebSocketDisconnect
from google import genai
from google.genai import types
from sqlalchemy import func, select

from app.core.config import settings
from app.core.db import SessionLocal
from app.core.security import decode_token
from app.models import Order, Product, User

router = APIRouter(tags=["voice"])
log = logging.getLogger("kalasetu.voice")

_SYSTEM = (
    "Tum 'Kala' ho — KalaSetu app ki AI awaaz-madadgaar, khaas Bharat ke kaarigaron "
    "(artisans) ke liye. Tum ChatGPT jaisi aam chatbot NAHI ho aur na hi koi 'language "
    "model'. Agar koi tumhara parichay poochhe to kaho: 'Main Kala hoon, KalaSetu par "
    "aapki madadgaar.' Tumhara kaam SIRF kaarigar ke kaam-dhandhe me madad karna hai:\n"
    "1) Business jaankari: unke order, kamai aur listed products — iske liye zaroori "
    "tools call karke ASLI aankde batao, kabhi aankde mat banao.\n"
    "2) Bikri ki salah: keemat kya rakhein, product ka description kaisa ho, zyada kaise "
    "bike, kaunsa maal chalta hai.\n"
    "3) App ki madad: 'photo kaise daalein', 'listing kaise banayein', 'order kaise "
    "accept karein' — chhote steps me samjhao.\n"
    "Agar sawaal kaarigar ke kaam se JUDA NAHI hai (jaise general knowledge, ganit, news, "
    "rajniti, ya kuch likhwana/poem/code) to pyaar se mana karo: 'Main aapke kaam — craft, "
    "bikri aur orders — me madad ke liye hoon.' aur wapas unke kaam par le aao.\n"
    "Kaarigar JIS bhaasha me baat kare USI bhaasha me (Hindi/English/koi Bhartiya bhaasha), "
    "poore jawab me sirf EK hi bhaasha, chhota aur saral jawab do (bhaasha saaf na pata ho "
    "to Hindi). Wo aksar padh-likh nahi sakte, isliye seedha aur aasan bolo."
)


def _tool_declarations() -> list[types.Tool]:
    return [
        types.Tool(
            function_declarations=[
                types.FunctionDeclaration(
                    name="get_orders",
                    description="Kaarigar ke abhi ke pending aur is mahine ke total orders ki ginti.",
                ),
                types.FunctionDeclaration(
                    name="get_earnings",
                    description="Kaarigar ki is mahine ki kamai (rupaye me).",
                ),
                types.FunctionDeclaration(
                    name="get_products",
                    description="Kaarigar ke kul aur bazaar me listed (bikri ke liye) products ki ginti.",
                ),
            ]
        )
    ]


# ---- tool implementations (scoped to the signed-in artisan) ----
def _run_tool(name: str, user_id: str) -> dict:
    db = SessionLocal()
    try:
        if name == "get_orders":
            base = select(func.count()).select_from(Order).where(Order.artisan_id == user_id)
            return {
                "pending": int(db.scalar(base.where(Order.status == "pending")) or 0),
                "total_this_month": int(db.scalar(base) or 0),
            }
        if name == "get_earnings":
            amt = db.scalar(
                select(func.coalesce(func.sum(Order.total_price), 0.0)).where(
                    Order.artisan_id == user_id, Order.status == "paid"
                )
            ) or 0.0
            return {"this_month_rupees": round(float(amt)), "currency": "INR"}
        if name == "get_products":
            total = db.scalar(
                select(func.count()).select_from(Product).where(Product.user_id == user_id)
            ) or 0
            listed = db.scalar(
                select(func.count()).select_from(Product).where(
                    Product.user_id == user_id, Product.status == "listed"
                )
            ) or 0
            return {"total": int(total), "listed": int(listed)}
        return {"error": "unknown tool"}
    finally:
        db.close()


def _live_config() -> types.LiveConnectConfig:
    return types.LiveConnectConfig(
        response_modalities=["AUDIO"],
        tools=_tool_declarations(),
        # transcript of Kala's speech -> forwarded to the app as live captions
        # (accessibility + lets the UI show what she said).
        output_audio_transcription=types.AudioTranscriptionConfig(),
        system_instruction=types.Content(parts=[types.Part(text=_SYSTEM)]),
    )


@router.websocket("/voice/live")
async def voice_live(ws: WebSocket):
    await ws.accept()

    # --- auth: artisan access token via ?token= ---
    token = ws.query_params.get("token")
    user_id = decode_token(token) if token else None
    if not user_id:
        await ws.send_text(json.dumps({"type": "error", "reason": "unauthorized"}))
        await ws.close(code=4401)
        return
    db = SessionLocal()
    try:
        user = db.get(User, user_id)
    finally:
        db.close()
    if user is None:
        await ws.close(code=4401)
        return

    client = genai.Client(
        vertexai=True, project=settings.gcp_project, location=settings.voice_location
    )
    try:
        async with client.aio.live.connect(
            model=settings.voice_model, config=_live_config()
        ) as session:
            await ws.send_text(json.dumps({"type": "ready"}))

            async def uplink():
                """Phone mic PCM (16 kHz) + control messages -> Gemini."""
                try:
                    while True:
                        m = await ws.receive()
                        if m.get("bytes") is not None:
                            await session.send_realtime_input(
                                audio=types.Blob(
                                    data=m["bytes"], mime_type="audio/pcm;rate=16000"
                                )
                            )
                        elif m.get("text"):
                            data = json.loads(m["text"])
                            if data.get("type") == "text" and data.get("text"):
                                # typed turn (accessibility / testing)
                                await session.send_client_content(
                                    turns=types.Content(
                                        role="user",
                                        parts=[types.Part(text=data["text"])],
                                    ),
                                    turn_complete=True,
                                )
                            elif data.get("type") == "end":
                                break
                except (WebSocketDisconnect, RuntimeError):
                    pass  # client closed the socket

            async def downlink():
                """Gemini -> phone. session.receive() yields one TURN then ends, so
                loop it: a tool call ends its turn silently and the spoken answer
                arrives on the next pass — keep draining until the session closes."""
                while True:
                    had_audio = False
                    alive = False
                    async for resp in session.receive():
                        alive = True
                        tc = getattr(resp, "tool_call", None)
                        if tc and tc.function_calls:
                            responses = [
                                types.FunctionResponse(
                                    id=fc.id, name=fc.name,
                                    response=_run_tool(fc.name, user_id),
                                )
                                for fc in tc.function_calls
                            ]
                            await session.send_tool_response(function_responses=responses)
                            await ws.send_text(json.dumps(
                                {"type": "tool", "names": [f.name for f in tc.function_calls]}))
                            continue
                        if getattr(resp, "data", None):
                            had_audio = True
                            await ws.send_bytes(resp.data)
                        sc = getattr(resp, "server_content", None)
                        if sc and getattr(sc, "interrupted", False):
                            await ws.send_text(json.dumps({"type": "interrupted"}))
                        ot = getattr(sc, "output_transcription", None) if sc else None
                        if ot and getattr(ot, "text", None):
                            await ws.send_text(json.dumps({"type": "caption", "text": ot.text}))
                    # one turn (receive pass) ended
                    if had_audio:
                        await ws.send_text(json.dumps({"type": "turn_complete"}))
                    if not alive:
                        break  # session closed

            up = asyncio.create_task(uplink())
            down = asyncio.create_task(downlink())
            done, pending = await asyncio.wait(
                {up, down}, return_when=asyncio.FIRST_COMPLETED
            )
            for t in pending:
                t.cancel()
    except WebSocketDisconnect:
        pass
    except Exception as e:  # noqa: BLE001
        log.warning("voice session error: %s", e)
        try:
            await ws.send_text(json.dumps({"type": "error", "reason": "session"}))
        except Exception:  # noqa: BLE001
            pass
    finally:
        try:
            await ws.close()
        except Exception:  # noqa: BLE001
            pass
