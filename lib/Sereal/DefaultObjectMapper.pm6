use v6.c;

use Sereal::ObjectMapper;

unit class Sereal::DefaultObjectMapper does
    Sereal::ObjectMapper;

method build-object(Str:D $name, $data) {
    require ::($name);
    return ::($name).new(|$data);
}
