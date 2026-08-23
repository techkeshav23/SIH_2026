"""dpdp consent columns

Revision ID: b2c3d4e5f6a7
Revises: a1b2c3d4e5f6
Create Date: 2026-08-22 05:40:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'b2c3d4e5f6a7'
down_revision: Union[str, None] = 'a1b2c3d4e5f6'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    with op.batch_alter_table('users', schema=None) as batch_op:
        batch_op.add_column(sa.Column('consent_at', sa.DateTime(), nullable=True))
        batch_op.add_column(sa.Column('consent_version', sa.String(), nullable=True))
    with op.batch_alter_table('buyers', schema=None) as batch_op:
        batch_op.add_column(sa.Column('consent_at', sa.DateTime(), nullable=True))
        batch_op.add_column(sa.Column('consent_version', sa.String(), nullable=True))


def downgrade() -> None:
    with op.batch_alter_table('buyers', schema=None) as batch_op:
        batch_op.drop_column('consent_version')
        batch_op.drop_column('consent_at')
    with op.batch_alter_table('users', schema=None) as batch_op:
        batch_op.drop_column('consent_version')
        batch_op.drop_column('consent_at')
