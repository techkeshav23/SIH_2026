"""reviews and notifications

Revision ID: a1b2c3d4e5f6
Revises: 131c5609cb49
Create Date: 2026-08-22 05:10:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'a1b2c3d4e5f6'
down_revision: Union[str, None] = '131c5609cb49'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table('reviews',
    sa.Column('id', sa.String(), nullable=False),
    sa.Column('product_id', sa.String(), nullable=False),
    sa.Column('buyer_id', sa.String(), nullable=True),
    sa.Column('author_name', sa.String(), nullable=True),
    sa.Column('rating', sa.Integer(), nullable=False),
    sa.Column('text', sa.Text(), nullable=True),
    sa.Column('created_at', sa.DateTime(), nullable=False),
    sa.ForeignKeyConstraint(['buyer_id'], ['buyers.id'], ),
    sa.ForeignKeyConstraint(['product_id'], ['products.id'], ),
    sa.PrimaryKeyConstraint('id')
    )
    with op.batch_alter_table('reviews', schema=None) as batch_op:
        batch_op.create_index(batch_op.f('ix_reviews_buyer_id'), ['buyer_id'], unique=False)
        batch_op.create_index(batch_op.f('ix_reviews_product_id'), ['product_id'], unique=False)

    op.create_table('notifications',
    sa.Column('id', sa.String(), nullable=False),
    sa.Column('recipient_id', sa.String(), nullable=False),
    sa.Column('recipient_role', sa.String(), nullable=False),
    sa.Column('kind', sa.String(), nullable=False),
    sa.Column('title', sa.String(), nullable=False),
    sa.Column('body', sa.Text(), nullable=True),
    sa.Column('read', sa.Boolean(), nullable=False),
    sa.Column('created_at', sa.DateTime(), nullable=False),
    sa.PrimaryKeyConstraint('id')
    )
    with op.batch_alter_table('notifications', schema=None) as batch_op:
        batch_op.create_index(batch_op.f('ix_notifications_created_at'), ['created_at'], unique=False)
        batch_op.create_index(batch_op.f('ix_notifications_recipient_id'), ['recipient_id'], unique=False)


def downgrade() -> None:
    with op.batch_alter_table('notifications', schema=None) as batch_op:
        batch_op.drop_index(batch_op.f('ix_notifications_recipient_id'))
        batch_op.drop_index(batch_op.f('ix_notifications_created_at'))
    op.drop_table('notifications')

    with op.batch_alter_table('reviews', schema=None) as batch_op:
        batch_op.drop_index(batch_op.f('ix_reviews_product_id'))
        batch_op.drop_index(batch_op.f('ix_reviews_buyer_id'))
    op.drop_table('reviews')
