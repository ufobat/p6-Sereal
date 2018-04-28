use v6.c;
unit class Sereal:ver<0.0.1>;

=begin pod

=head1 NAME

Sereal - blah blah blah

=head1 SYNOPSIS

  use Sereal;

=head1 DESCRIPTION

Sereal is ...

=head1 AUTHOR

Martin Barth <martin@senfdax.de>

=head1 COPYRIGHT AND LICENSE

Copyright 2018 Martin Barth

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.

=end pod

use Sereal::Decoder;

sub decode_file($file) is export {
    my $data = $file.IO.slurp(:bin);
    my $decoder = Sereal::Decoder.new();
    $decoder.decode($data);
}
