unit class Sereal::Decoder;

use Sereal::Header;

has Blob $!data;
has Int $!position;
has Int $!size;
has Int $!protocol-version;
has Int $!encoding;
has Int $!user-header-position;
has Int $!user-header-size;

# configuration
has Bool $!refuse-snappy = False;

# TODO: just a blob of bytes
method decode(Blob[uint8] $blob) {
    self!set-data($blob);
    self!parse-header();
}

method !set-data($blob) {
    $!data     = $blob;
    $!size     = $blob.elems;
    $!position = 0;
}

method !parse-header() {
    self!check-header();
    self!check-proto-and-flags();
    self!check-header-suffix();
}

method !check-header() {
    if $!size - $!position < 4 {
        die 'Invalid Sereal header: too few bytes';
    }

    my $magic = $!data[ $!position + 0 ] +< 24 +
                $!data[ $!position + 1 ] +< 16 +
                $!data[ $!position + 2 ] +<  8 +
                $!data[ $!position + 3 ] +<  0;
    $!position += 4;

    if $magic != MAGIC && $magic != MAGIC_V3 {
        die "Invalid Seareal header: $magic doesn't match magic"
    }
}

method !check-proto-and-flags() {
    if $!size - $!position < 1 {
        die 'Invalid Sereal header: no protocol/version byte';
    }
    my $protoAndFlags = $!data[ $!position++ ];

    $!protocol-version = $protoAndFlags +& 15;
    unless 0 <= $!protocol-version <= 4 {
        die "Invalid Serial header: unsupported protocol version $!protocol-version";
    }

    $!encoding = $protoAndFlags +& +^15  +> 4;
    if $!encoding == 1|2 && $!refuse-snappy {
        die "Unsupported encoding: Snappy";
    } elsif $!encoding == 4 && $!protocol-version < 4 {
        die "Unsupported encoding zstd for protocol version $!protocol-version";
    } elsif $!encoding < 0 || $!encoding > 4 {
        die "Unsupported encoding: unknown";
    }
}

method !check-header-suffix() {
    my Int $suffix-size = self!read-varint();
    my Int $base-position = $!position;

    $!user-header-size = 0;
    if $suffix-size {
        my Int $bitfield = $!data[$!position++];
        if $bitfield +& 1 {
            # least significant bit is set
            # <USER-META-DATA> is following
            $!user-header-position = $!position;
            $!user-header-size = $suffix-size - 1;
        }
    }

    $!position = $base-position + $suffix-size;
}

method !read-varint(--> Int) {
    my Int $uv = 0;
    my Int $lshift = 0;

    my Int $b = $!data[$!position++];
    while $!position < $!size and $b +& 128 {
        $uv = $uv +| (($b +& 127) +< $lshift);
        $b = $!data[$!position++];
        $lshift += 7;
    }
    $uv = $uv +| $b +< $lshift;
    return $uv;
}
