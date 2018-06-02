unit class Sereal::Decoder;

use Sereal::Header;
use Sereal::ObjectMapper;
use Sereal::DefaultObjectMapper;
use NativeCall;

has Blob $!data;
has Int $!position;
has Int $!size;
has Int $!protocol-version;
has Int $!encoding;
has Int $!user-header-position;
has Int $!user-header-size;
has Int $!track-offset;
has Hash %!tracked;

# configuration
has Bool $.refuse-snappy = False;
has Bool $.debug = False;
has Sereal::ObjectMapper $.object-mapper = Sereal::DefaultObjectMapper.new();

method decode() {
    self!parse-header();

    if $!encoding == 1|2 {
        self!uncompress-snappy();
    } elsif $!encoding == 3 {
        self!uncompress-zlib();
    } elsif $!encoding == 4 {
        self!uncompress-zstd();
    }

    $!track-offset = $!protocol-version == 1
    ?? 1           # offsets relative to the start of the body
    !! $!position; # offsets relative to the the document header

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
    %!tracked = Hash.new;
}

method !debug(Str:D $msg) {
    say $msg if $!debug;
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

method !read-zigzag(--> Int) {
    my $i = self!read-varint();
    my $z = floor( ($i+1) / 2);
    $z = $z * -1 unless $i %% 2;
    self!debug("read-zigzag() --> $z");
    return $z
}

method !read-float(--> Num) {
    my $blob = $!data.subbuf($!position, 4);
    $!position += 4;
    my Num $float = nativecast(Pointer[num32], $blob).deref;
    self!debug("read-float() --> $float");
    return $float;
}

method !read-double(--> Num) {
    my $blob = $!data.subbuf($!position, 8);
    $!position += 8;
    my Num $double = nativecast(Pointer[num64], $blob).deref;
    self!debug("read-double() --> $double");
    return $double;
}

method !read-long-double(--> Num) {
    X::NYI.new(feature => 'read-long-double').throw;
    # it sesms that there is no num128
    # so we need to implement the IEEE manually
}

method !read-arrayref(Int $elems) {
    self!debug("read-arrayref()");
    my @array;
    for 0..^$elems {
        my $val = self!read-single-value();
        @array.push: $val;
    }
    self!debug("read-arrayref() --> { @array.perl }");
    return @array
}

method !read-refn(Int $track) {
    self!debug("read-refn()");
    my $thing = self!read-single-value();
    self!debug("read-refn() --> { $thing.perl }");
    self!set-tracked($track, $thing) if $track;
    return $thing;
}

method !read-refp() {
    self!debug("read-refp()");
    my $offset = self!read-varint();
    return self!get-tracked($offset);
}

method !read-alias() {
    self!debug("read-alias()");
    my $offset = self!read-varint();
    return self!get-tracked($offset);
}

method !read-hash(Int $track, Int:D $elems) {
    self!debug("read-hash()");
    my %hash;
    for 0..^$elems {
        my $str = self!read-string();
        my $val = self!read-single-value();
        %hash{$str} = $val;
    }

    self!set-tracked($track, %hash) if $track;
    self!debug("read-hash() --> { %hash.perl }");
    return %hash;
}

method !read-utf8(--> Str:D) {
    self!debug("read-utf8()");
    my Int $length = self!read-varint();
    my $val = self!read-blob($length);
    return $val.decode('utf-8');
}

method !read-blob(Int:D $length --> Blob:D) {
    my $val = $!data.subbuf($!position, $length);
    $!position += $length;
    return $val;
}

method !read-binary(--> Blob) {
    my Int $length = self!read-varint();
    my $out = self!read-blob($length);
    self!debug("read-binary() --> { $out.perl }");
    return $out;
}

method !read-short-binary(Int:D $length--> Blob) {
    my $out = self!read-blob($length);
    self!debug("read-short-binary() --> { $out.perl }");
    return $out;
}

method !read-string-copy() { ... }

method !read-string(--> Str:D) {
    self!debug("read-string()");
    my Str $out;
    my $tag = $!data[$!position++];
    if $tag +& SRL_HDR_SHORT_BINARY {
        my $length = $tag +& 31; # lower 5 bits
        $out = self!read-short-binary($length).decode('latin1');
    } elsif $tag == SRL_HDR_BINARY {
        $out = self!read-binary().decode('latin1');
    } elsif $tag == SRL_HDR_STR_UTF8 {
        $out = self!read-utf8();
    } elsif $tag == SRL_HDR_COPY {
        $out = self!read-string-copy();
    } else {
        die "Tag $tag is not a String";
    }
    return $out;
}

method !read-object {
    self!debug('read-object()');
    my $classname = self!read-string();
    my $object = self!read-object-by-name($classname);
    return $object;
}
method !read-objectv {
    self!debug('read-objectv()');
    my $classname = self!read-string-copy();
    my $object = self!read-object-by-name($classname);
    return $object;
}
method !read-object-by-name(Str:D $name) {
    my $data = self!read-single-value();
    my $object = $!object-mapper.build-object($name, $data);
    return $object;
}

method !read-object-freeze() {
    self!debug('read-object-freeze()');
    my $classname = self!read-string();
    my $object = self!read-object-via-thaw($classname);
    return $object;
}
method !read-objectv-freeze() {
    self!debug('read-objectv-freeze()');
    my $classname = self!read-string-copy();
    my $object = self!read-object-via-thaw($classname);
    return $object;
}
method !read-object-via-thaw(Str:D $name) {
    my $data = self!read-single-value();
    require ::($name);
    my $object = ::($name).THAW($data);
    return $object
}

method !read-copy() {
    self!debug('read-copy()');
    # read something that has already been decoded
    my $pos = self!read-varint();
    my $current_pos = $!position;
    $!position = $pos;
    my $val = self!read-single-value();
    $!position = $current_pos;
    return $val;
}

method !read-weaken() {
    self!debug('read-weaken()');
    # next this must be a reference - we're just need to weaken it
    my $val = self!read-single-value();
    return $val;
}

method !read-regexp() {
    self!debug('read-regexp()');
    my $pattern = self!read-single-value();
    my $modifiers = self!read-single-value();
    X::NYI.new(feature => 'read-regexp').throw;
}

method !read-single-value() {
    self!debug('read-single-value()');
    die "Unexpected end of data at byte $!position" if $!size <= $!position;

    my Int $tag = $!data[$!position++];
    my Int $track;
    if $tag +& SRL_HDR_TRACK_FLAG {
        # highest bit is set
        $track = $!position;
        self!debug("Track this value at $track - byte: $tag");
        # remove track flag
        $tag = $tag +&  +^SRL_HDR_TRACK_FLAG;
    }

    self!debug('read-single-value() - TAG: ' ~ $tag);

    # keep the oder accoring to the constant value
    my $out;
    if $tag <= SRL_HDR_POS_HIGH {
        $out = $tag;
        self!debug("read-single-value() - POS_HIGH - $out");
    } elsif $tag <= SRL_HDR_NEG_HIGH {
        $out = $tag - 32;
        self!debug("read-single-value() - NEG_HIGH - $out");
    } elsif $tag == SRL_HDR_VARINT {
        $out = self!read-varint();
        self!debug("read-single-value() - VARINT - $out");
    } elsif $tag == SRL_HDR_ZIGZAG {
        $out = self!read-zigzag();
    } elsif $tag == SRL_HDR_FLOAT {
        $out = self!read-float();
    } elsif $tag == SRL_HDR_DOUBLE {
        $out = self!read-double();
    } elsif $tag == SRL_HDR_LONG_DOUBLE {
        $out = self!read-long-double();
    } elsif $tag == SRL_HDR_UNDEF {
        $out = Nil;
        self!debug("read-single-value() - UNDEF - Nil");
    } elsif $tag == SRL_HDR_BINARY {
        $out = self!read-binary();
    } elsif $tag == SRL_HDR_STR_UTF8 {
        $out = self!read-utf8();
    } elsif $tag == SRL_HDR_REFN {
        $out = self!read-refn($track);
    } elsif $tag == SRL_HDR_REFP {
        $out = self!read-refp();
    } elsif $tag == SRL_HDR_HASH {
        my $elems = self!read-varint();
        $out = self!read-hash($track, $elems);
    } elsif $tag == SRL_HDR_ARRAY {
        my $elems = self!read-varint();
        $out = self!read-arrayref($elems);
    } elsif $tag == SRL_HDR_OBJECT {
        $out = self!read-object();
    } elsif $tag == SRL_HDR_OBJECTV {
        $out = self!read-objectv();
    } elsif $tag == SRL_HDR_ALIAS {
        $out = self!read-alias();
    } elsif $tag == SRL_HDR_COPY {
        $out = self!read-copy();
    } elsif $tag == SRL_HDR_WEAKEN {
        $out = self!read-weaken();
    } elsif $tag == SRL_HDR_REGEXP {
        $out = self!read-regexp();
    } elsif $tag == SRL_HDR_OBJECT_FREEZE {
        $out = self!read-object-freeze();
    } elsif $tag == SRL_HDR_OBJECTV_FREEZE {
        $out = self!read-objectv-freeze();
    } elsif SRL_HDR_RESERVED_LOW <= $tag <= SRL_HDR_RESERVED_HIGH {
        # ignore
    } elsif SRL_HDR_CANONICAL_UNDEF == $tag {
        $out = Nil;
        self!debug("read-single-value() - CANONICAL_UNDEF - Nil");
    } elsif SRL_HDR_FALSE == $tag {
        $out = False;
        self!debug("read-single-value() - FALSE - False");
    } elsif SRL_HDR_TRUE == $tag {
        $out = True;
        self!debug("read-single-value() - TRUE - True");
    } elsif SRL_HDR_PAD == $tag {
        self!debug("read-single-value() - PAD - ignore");
        $out = self!read-single-value();
    } elsif $tag < SRL_HDR_ARRAYREF {
        self!debug("read-single-value() - ARRAYREF");
        # number of elments is stored in the lower nibble
        my $elems = $tag +& 0x0F;
        $out = self!read-arrayref($elems);
    } elsif $tag < SRL_HDR_HASHREF {
        self!debug("read-single-value() - HASHREF");
        # number of elments is stored in the lower nibble
        my $elems = $tag +& 0x0F;
        $out = self!read-hash($elems);
    } elsif $tag <= SRL_HDR_SHORT_BINARY {
        # number of elments is stored in the lower 5 bits!
        self!debug("read-single-value() - SHORT BINARY");
        my $elems = $tag +& 0x1F;
        $out = self!read-short-binary($elems);
    } else {
        die "Sereal Tag $tag not supported";
    }

    self!debug("read-single-value() --> { $out.perl }");
    return $out;
}

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

# tracking values
method !get-tracked(Int:D $offset) {
    die "Getting tracked item with offset $offset which is not tracked"
    unless %!tracked{ $offset }:exists;

    return %!tracked{ $offset };
}

method !set-tracked(Int:D $offset is copy, Mu $thingy) {
    $offset -= $!track-offset;
    %!tracked{$offset} = $thingy;
}
