unit class Sereal::Decoder;

use Sereal::Header;

has Blob $!data;
has Int $!position;
has Int $!size;
has Int $!protocol-version;
has Int $!encoding;
has Int $!user-header-position;
has Int $!user-header-size;
has Int $!track-offset;

# configuration
has Bool $!refuse-snappy = False;

method decode() {
    self!parse-header();

    if $!encoding == 1|2 {
        self!uncompress-snappy();
    } elsif $!encoding == 3 {
        self!uncompress-zlib();
    } elsif $!encoding == 4 {
        self!uncompress-zstd();
    }

    # offsets start with 1
    $!track-offset = $!protocol-version == 1
    ?? $!position + 1 # offsets relative to the the document header
    !! 1;             # offsets relative to the start of the body

    return self!read-single-value();
}

method decode-header() {
    self!parse-header();

    unless $!user-header-size > 0 {
        die "Sereal user header not present";
    }

    my Int $original-position = $!position;
    my Int $original-size = $!size;

    $!position = $!user-header-position;
    $!size = $!user-header-position + $!user-header-size;
    return self!read-single-value();

    LEAVE {
        # restore original values
        $!size = $original-size;
        $!position = $original-position;
        # TODO: reset tracked
    }
}

method set-data(Blob[uint8] $blob) {
    # set data and known values
    $!data     = $blob;
    $!size     = $blob.elems;
    $!position = 0;

    # reset all parsed information
    $!protocol-version = Int;
    $!encoding = Int;
    $!user-header-position = Int;
    $!user-header-size = Int;
}

method !parse-header() {
    return if $!user-header-size.defined;

    self!check-header();
    self!check-proto-and-flags();
    self!check-header-suffix();
}

method !check-header() {
    unless $!data.defined {
        die 'No data set';
    }

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

method !read-single-value() { ... }

# uncompression
method !uncompress-snappy() { X::NYI.new(feature => 'snappy compression').throw }
method !uncompress-zstd() { X::NYI.new(feature => 'zstd compression').throw }
method !uncompress-zlib() {
    X::NYI.new(feature => 'zlib compression').throw;
    require Compress::Zlib;

    # read-varint updates $!position
    my Int $uncompressed-length = self!read-varint();
    my Int $compressed-length = self!read-varint();
    my Blob $uncompressd = Compress::Zlib::uncompress( $!data.subbuf($!position) );

    # update date and length
    # position did not change
    $!data.subbuf-rw($!position);
    $!size = $!data.elems;
}
