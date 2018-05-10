unit module Sereal::Header;

our constant MAGIC    is export = 0x3d73726c;
our constant MAGIC_V3 is export = 0x3df3726c;

our constant SRL_HDR_POS_HIGH        is export = 15;
our constant SRL_HDR_NEG_HIGH        is export = 31;
our constant SRL_HDR_VARINT          is export = 32;
our constant SRL_HDR_ZIGZAG          is export = 33;
our constant SRL_HDR_FLOAT           is export = 34;
our constant SRL_HDR_DOUBLE          is export = 35;
our constant SRL_HDR_LONG_DOUBLE     is export = 36;
our constant SRL_HDR_UNDEF           is export = 37;
our constant SRL_HDR_BINARY          is export = 38;
our constant SRL_HDR_STR_UTF8        is export = 39;
our constant SRL_HDR_REFN            is export = 40;
our constant SRL_HDR_REFP            is export = 41;
our constant SRL_HDR_HASH            is export = 42;
our constant SRL_HDR_ARRAY           is export = 43;
our constant SRL_HDR_OBJECT          is export = 44;
our constant SRL_HDR_OBJECTV         is export = 45;
our constant SRL_HDR_ALIAS           is export = 46;
our constant SRL_HDR_COPY            is export = 47;
our constant SRL_HDR_WEAKEN          is export = 48;
our constant SRL_HDR_REGEXP          is export = 49;
our constant SRL_HDR_OBJECT_FREEZE   is export = 50;
our constant SRL_HDR_OBJECTV_FREEZE  is export = 51;
our constant SRL_HDR_RESERVED_LOW    is export = 52;
our constant SRL_HDR_RESERVED_HIGH   is export = 56;
our constant SRL_HDR_CANONICAL_UNDEF is export = 57;
our constant SRL_HDR_FALSE           is export = 58;
our constant SRL_HDR_TRUE            is export = 59;
# not (yet) implemented
our constant SRL_HDR_PAD             is export = 63;
our constant SRL_HDR_ARRAYREF        is export = 64;
our constant SRL_HDR_SHORT_BINARY    is export = 96;
our constant SRL_HDR_TRACK_FLAG      is export = 128;
