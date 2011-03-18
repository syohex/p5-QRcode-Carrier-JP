package QRCode::Carrier::JP::ContactInfo;
use strict;
use warnings;

use Carp ();
use Imager::QRCode;

use utf8;
use Encode ();
use Lingua::JA::Regular::Unicode ();

use MIME::Base64 ();
use URI::Escape ();

use Class::Accessor::Lite (
    rw => [
        qw/id memory name1 name2
           mail_addresses telephones address qrcode /
       ],
);

my @CARRIERS = qw/docomo au softbank/;

my %valid_pattern = (
    mail_addresses => qr/^[^@]+\@[^@]+$/xms,
    telephones     => qr/^[0-9#P\-]+$/xms,
);

my %limit_length = (
    memory         => 80,
    name1          => 24,
    name2          => 24,
    mail_addresses => 60,
    telephones     => 24,
    address        => 80,
);

sub new {
    my ($class, $args) = @_;

    my $obj = bless {}, $class;

    $obj->id($args->{id});

    unless (defined $args->{name1}) {
        Carp::croak("Not specified 'name1' parameter\n");
    }

    $obj->name1($args->{name1});

    unless (exists $args->{name2}) {
        Carp::croak("Not specified 'name2' parameter\n");
    }

    $obj->name2($args->{name2});

    for my $param (qw/mail_addresses telephones/) {
        unless (ref $args->{$param} eq 'ARRAY' && scalar @{$args->{$param}} > 0) {
            Carp::croak($obj->id, ":$param paramter must be ARRAY reference"
                            , " and its length must be grater than 0\n");
        }

        $obj->$param($args->{$param});
    }

    for my $param (qw/memory address/) {
        my $val = defined $args->{$param} ? $args->{$param} : '';
        $obj->$param($val);
    }

    return $obj;
}

sub validate {
    my $self = shift;

    my $name1 = $self->name1;
    unless ($name1 =~ m{\w+ \s \w+}xms) {
        Carp::croak("name1 parameter $name1 is invalid.\n"
           , "You must separate family name and first name with a space\n");
    }

    # '+ 1' means a space which separates family name and first name
    my $shift_jis_name1= Encode::encode('shift_jis', $name1);
    _check_byte_length($shift_jis_name1, $limit_length{name1} + 1);

    my $name2 = $self->name2;
    unless ($name2 =~ m{(\w+) \s (\w+)}xms) {
        Carp::croak("name2 parameter $name2 is invalid.\n"
           , "You must separate family name and first name with a space\n");
    }

    my ($family, $first) = ($1, $2);

    # '+ 1' means a space which separates family name and first name
    my $hankaku_name2 = Lingua::JA::Regular::Unicode::katakana_z2h($name2);
    my $shift_jis_name2 = Encode::encode('shift_jis', $hankaku_name2);
    _check_byte_length($shift_jis_name2, $limit_length{name2} + 1);

    my $katakana = Encode::decode_utf8('ァ-ン');
    my $katakana_regexp = qr{^[$katakana]+$}xms;
    for my $part ($family, $first) {
        unless ($part =~ m{$katakana_regexp}) {
            Carp::croak("name2 parameter must consist of KATAKANA, $part\n");
        }
    }

    for my $parameter (qw/mail_addresses telephones/) {
        my $array_ref = $self->$parameter;

        if (scalar @{$array_ref} > 3) {
            Carp::croak("$parameter too long. It must be less than equal 3.\n");
        }

        my $regexp = $valid_pattern{$parameter};
        for my $element (@{$array_ref}) {
            unless ($element =~ m{$regexp}) {
                Carp::croak("$parameter invalid: $element\n");
            }

            _check_byte_length($element, $limit_length{$parameter});
        }
    }

    ## optional parameters
    for my $key (qw/memory address/) {
        my $shift_jis_val = Encode::encode('shift_jis', $self->$key);
        _check_byte_length($shift_jis_val, $limit_length{$key});
    }
}

sub qrcode_as_base64 {
    my ($self, $carrier) = @_;

    _check_carrier($carrier);

    my $qrcode = Imager::QRCode->new(
        version       => 1,
        level         => 'M',
        casesensitive => 1,
        lightcolor    => Imager::Color->new(255, 255, 255),
        darkcolor     => Imager::Color->new(0, 0, 0),
    );

    my $imager = $qrcode->plot( $self->qrcode->{$carrier} );
    $imager->write(
        data => \my $png_data,
        type => 'png',
    );

    return MIME::Base64::encode_base64($png_data);
}

sub output_qrcode {
    my ($self, $carrier, $output) = @_;

    _check_carrier($carrier);

    unless (defined $output) {
        Carp::croak("Output file is not specified\n");
    }

    my $qrcode = Imager::QRCode->new(
        version       => 1,
        level         => 'M',
        casesensitive => 1,
        lightcolor    => Imager::Color->new(255, 255, 255),
        darkcolor     => Imager::Color->new(0, 0, 0),
    );

    my $imager = $qrcode->plot( $self->qrcode->{$carrier} );
    $imager->write(
        file => $output,
    );
}

sub _check_carrier {
    my $carrier = shift;

    unless (defined $carrier) {
        Carp::croak("Error not specify carrier(@CARRIERS)\n");
    }

    unless (grep { $carrier eq $_ } @CARRIERS) {
        Carp::croak("Error invalid carrier $carrier\n");
    }
}

sub create_qr_code {
    my $self = shift;

    my %qrdata_generator = (
        docomo   => \&_create_docomo_data,
        au       => \&_create_au_data,
        softbank => \&_create_softbank_data,
    );

    my %imager_qrcode;
    for my $carrier (@CARRIERS) {
        $imager_qrcode{$carrier} = $qrdata_generator{$carrier}->($self);
    }

    $self->qrcode(\%imager_qrcode);
}

sub _create_docomo_data {
    my $self = shift;

    my @params;

    my ($family_name, $first_name) = split /\s/, $self->name1;
    my $name_param = join ',',  $family_name, $first_name;
    push @params, "MECARD:N:" . $name_param;

    my ($family_kana, $first_kana) = map {
        Lingua::JA::Regular::Unicode::katakana_z2h($_);
    } split /\s/, $self->name2;

    my $sound_param = join ",", $family_kana, $first_kana;
    push @params, "SOUND:" . $sound_param;

    for my $telephone (@{$self->telephones}) {
        $telephone =~ s{-}{}g;
        push @params, "TEL:" . $telephone;
    }

    for my $email (@{$self->mail_addresses}) {
        push @params, "EMAIL:" . $email;
    }

    my $note = $self->memory;
    push @params, "NOTE:" . $note;

    my $data = join ';', @params;
    $data .= ';;';

    Encode::encode('shift_jis', $data);
}

sub _create_au_data {
    my $self = shift;

    my $data = $self->_common_au_and_softbank();

    # ADD(address)
    $data .= "ADD:" . $self->address;
    $data .= "\015\012";

    Encode::encode('shift_jis', $data);
}

sub _create_softbank_data {
    my $self = shift;

    my $data = $self->_common_au_and_softbank();
    Encode::encode('shift_jis', $data);
}

sub _common_au_and_softbank {
    my $self = shift;
    my @params;

    push @params, "MEMORY:" . $self->memory;

    (my $name1 = $self->name1) =~ s{\s}{}xms;
    push @params, "NAME1:" . $name1;

    (my $name2 = $self->name2) =~ s{\s}{}xms;
    my $hankaku_name2 = Lingua::JA::Regular::Unicode::katakana_z2h($name2);
    push @params, "NAME2:" . $hankaku_name2;

    {
        my $i = 1;
        for my $mail_address (@{$self->mail_addresses}) {
            push @params, "MAIL${i}:" . $mail_address;
            $i++;
        }
    }

    {
        my $i = 1;
        for my $telephone (@{$self->telephones}) {
            $telephone =~ s{-}{}g;
            push @params, "TEL${i}:" . $telephone;
            $i++;
        }
    }

    my $data = join "\015\012", @params;

    $data .= "\015\012";
    $data;
}

sub _check_byte_length {
    my ($string, $limit) = @_;

    {
        use bytes;

        if (length $string > $limit) {
            Carp::croak("$string is too long\n");
        }
    }
}

sub as_string {
    my $self = shift;

    my @attrs;

    push @attrs, "名前:";
    push @attrs, $self->name1 . "(" . $self->name2 . ")";

    push @attrs, "メールアドレス:";
    push @attrs, $_ for @{$self->mail_addresses};

    push @attrs, "電話番号:";
    push @attrs, $_ for @{$self->telephones};

    if ($self->address) {
        push @attrs, "住所:";
        push @attrs, $self->address;
    }

    if ($self->memory) {
        push @attrs, "メモ:";
        push @attrs, $self->memory;
    }

    return join "\n", @attrs;
}

1;
__END__

=encoding utf-8

=head1 NAME

QRCode::Carrier::JP::ContactInfo - Contact information

=head1 SYNOPSIS

  use QRCode::Carrier::JP::ContactInfo;

=head1 DESCRIPTION

QRCode::Carrier::JP::ContactInfo is

=head1 INTERFACE

=head1 AUTHOR

Syohei YOSHIDA E<lt>syohex@gmail.comE<gt>

=head1 SEE ALSO

C<Imager::QRCode>

=head1 LICENSE

Copyright 2011- Syohei YOSHIDA

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
