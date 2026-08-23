"""addresses and order shipping snapshot

Revision ID: c3d4e5f6a7b8
Revises: b2c3d4e5f6a7
Create Date: 2026-08-22 06:05:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'c3d4e5f6a7b8'
down_revision: Union[str, None] = 'b2c3d4e5f6a7'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table('addresses',
    sa.Column('id', sa.String(), nullable=False),
    sa.Column('buyer_id', sa.String(), nullable=False),
    sa.Column('name', sa.String(), nullable=False),
    sa.Column('phone', sa.String(), nullable=False),
    sa.Column('line1', sa.String(), nullable=False),
    sa.Column('line2', sa.String(), nullable=True),
    sa.Column('city', sa.String(), nullable=False),
    sa.Column('state', sa.String(), nullable=False),
    sa.Column('pincode', sa.String(), nullable=False),
    sa.Column('is_default', sa.Boolean(), nullable=False),
    sa.Column('created_at', sa.DateTime(), nullable=False),
    sa.ForeignKeyConstraint(['buyer_id'], ['buyers.id'], ),
    sa.PrimaryKeyConstraint('id')
    )
    with op.batch_alter_table('addresses', schema=None) as batch_op:
        batch_op.create_index(batch_op.f('ix_addresses_buyer_id'), ['buyer_id'], unique=False)

    with op.batch_alter_table('orders', schema=None) as batch_op:
        batch_op.add_column(sa.Column('ship_name', sa.String(), nullable=True))
        batch_op.add_column(sa.Column('ship_phone', sa.String(), nullable=True))
        batch_op.add_column(sa.Column('ship_address', sa.Text(), nullable=True))


def downgrade() -> None:
    with op.batch_alter_table('orders', schema=None) as batch_op:
        batch_op.drop_column('ship_address')
        batch_op.drop_column('ship_phone')
        batch_op.drop_column('ship_name')

    with op.batch_alter_table('addresses', schema=None) as batch_op:
        batch_op.drop_index(batch_op.f('ix_addresses_buyer_id'))
    op.drop_table('addresses')
