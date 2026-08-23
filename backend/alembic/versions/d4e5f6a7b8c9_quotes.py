"""quotes (B2B RFQ negotiation)

Revision ID: d4e5f6a7b8c9
Revises: c3d4e5f6a7b8
Create Date: 2026-08-23 06:30:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'd4e5f6a7b8c9'
down_revision: Union[str, None] = 'c3d4e5f6a7b8'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table('quotes',
    sa.Column('id', sa.String(), nullable=False),
    sa.Column('product_id', sa.String(), nullable=False),
    sa.Column('buyer_id', sa.String(), nullable=False),
    sa.Column('artisan_id', sa.String(), nullable=False),
    sa.Column('quantity', sa.Integer(), nullable=False),
    sa.Column('buyer_price', sa.Float(), nullable=False),
    sa.Column('artisan_price', sa.Float(), nullable=True),
    sa.Column('agreed_price', sa.Float(), nullable=True),
    sa.Column('list_price', sa.Float(), nullable=True),
    sa.Column('status', sa.String(), nullable=False),
    sa.Column('turn', sa.String(), nullable=False),
    sa.Column('message', sa.Text(), nullable=True),
    sa.Column('order_id', sa.String(), nullable=True),
    sa.Column('created_at', sa.DateTime(), nullable=False),
    sa.Column('updated_at', sa.DateTime(), nullable=False),
    sa.ForeignKeyConstraint(['artisan_id'], ['users.id'], ),
    sa.ForeignKeyConstraint(['buyer_id'], ['buyers.id'], ),
    sa.ForeignKeyConstraint(['product_id'], ['products.id'], ),
    sa.PrimaryKeyConstraint('id')
    )
    with op.batch_alter_table('quotes', schema=None) as batch_op:
        batch_op.create_index(batch_op.f('ix_quotes_artisan_id'), ['artisan_id'], unique=False)
        batch_op.create_index(batch_op.f('ix_quotes_buyer_id'), ['buyer_id'], unique=False)
        batch_op.create_index(batch_op.f('ix_quotes_product_id'), ['product_id'], unique=False)
        batch_op.create_index(batch_op.f('ix_quotes_status'), ['status'], unique=False)


def downgrade() -> None:
    with op.batch_alter_table('quotes', schema=None) as batch_op:
        batch_op.drop_index(batch_op.f('ix_quotes_status'))
        batch_op.drop_index(batch_op.f('ix_quotes_product_id'))
        batch_op.drop_index(batch_op.f('ix_quotes_buyer_id'))
        batch_op.drop_index(batch_op.f('ix_quotes_artisan_id'))
    op.drop_table('quotes')
