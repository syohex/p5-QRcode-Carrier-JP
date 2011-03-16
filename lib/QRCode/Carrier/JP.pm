package QRCode::Carrier::JP;
use strict;
use warnings;

use 5.008_001;
our $VERSION = '0.01';

use Carp ();
use Encode ();
use Encode::JP::H2Z;
use File::Spec ();
use Imager::QRCode;

our $ENCODE_CHARSET = 'utf-8';

my @carriers = qw/docomo au softbank/;
my %qr_func = (
    docomo   => \&_create_docomo_data,
    au       => \&_create_au_data,
    softbank => \&_create_softbank_data,
);

my %valid_pattern = (
    mail_addresses => qr/^[^@]+\@[^@]+$/xms,
    telephones     => qr/^[0-9#P\-]+$/xms,
);

my %limit_length = (
    memory         => 80,
    name1          => 24,
    name2          => 24,
    mail           => 60,
    telephones     => 24,
    mail_addresses => 80,
);

sub new {
    my ($class, $args) = @_;

    my $attrs = {};

    $attrs->{debug}    = delete $args->{debug} || 0;
    $attrs->{qrcode} = Imager::QRCode->new(
        version       => 1,
        level         => 'M',
        casesensitive => 1,
        lightcolor    => Imager::Color->new(255, 255, 255),
        darkcolor     => Imager::Color->new(0, 0, 0),
    );

    bless $attrs, $class;
}

sub run {
    my ($self, $contact_info) = @_;

    unless (ref $contact_info eq "HASH") {
        Carp::croak("contact_info parameter must be HASH reference\n");
    }

    $self->_validate_contact_info($contact_info);

    my $retval = {};
    while ( my ($name, $info) = each %{$contact_info} ) {
        for my $carrier (@carriers) {
            my $data = $qr_func{$carrier}->($self, $info);
            if ($self->{debug} > 2) {
                my $decoded = Encode::decode('shift_jis', $data);
                $decoded =~ s{\r\n$}{\n}xmsg;
                printf STDERR "\n%s\n",
                    Encode::encode($ENCODE_CHARSET, $decoded);
            }

            my $output = File::Spec->catfile(
                $self->{output_dir}, $carrier, "${name}.png"
            );

            my $imager = $self->{qrcode}->plot($data);

            $retval->{$name}->{$carrier} = $imager;
        }
    }

    $retval;
}

sub _validate_contact_info {
    my ($self, $contact_info) = @_;

    while ( my ($name, $info) = each %{$contact_info} ) {
        $self->_validate_contact_info_each($name, $info);
    }
}

sub _validate_contact_info_each {
    my ($self, $name, $info) = @_;

    my $encoded_name = Encode::encode($ENCODE_CHARSET, "$name");

    if ($self->{debug}) {
        printf STDERR "Validate %s's contact information.... ", $encoded_name;
    }

    ## mandatory parameters
    unless (exists $info->{name1}) {
        Carp::croak("Not specified 'name1' parameter\n");
    }

    unless ($info->{name1} =~ m{\w+ \s \w+}xms) {
        Carp::croak("name1 parameter."
           , "You must separate family name and first name with a space\n");
    }

    # '+ 1' means a space which separates family name and first name
    _check_byte_length($info->{name1}, $limit_length{name1} + 1);

    unless (exists $info->{name2}) {
        Carp::croak("Not specified 'name2' parameter\n");
    }

    unless ($info->{name2} =~ m{(\w+) \s (\w+)}xms) {
        Carp::croak("name2 parameter."
           , "You must separate family name and first name with a space\n");
    }

    # '+ 1' means a space which separates family name and first name
    _check_byte_length($info->{name1}, $limit_length{name2});

    my ($family, $first) = ($1, $2);
    my $katakana = Encode::decode_utf8('ァ-ン');
    my $katakana_regexp = qr{^[$katakana]+$}xms;
    for my $part ($family, $first) {
        unless ($part =~ m{$katakana_regexp}) {
            Carp::croak("name2 parameter must consist of KATAKANA, $part\n");
        }
    }

    for my $parameter (qw/mail_addresses telephones/) {
        unless (exists $info->{$parameter}) {
            Carp::croak("$parameter parameter is mandatory parameter.\n");
        }

        unless (ref $info->{$parameter} eq 'ARRAY') {
            Carp::croak("$parameter parameter must be ARRAY ref.\n");
        }

        if (scalar @{$info->{$parameter}} > 3) {
            Carp::croak("$parameter too long. It must be less than equal 3.\n");
        }

        _check_byte_length($info->{name1}, $limit_length{$parameter});

        my $regexp = $valid_pattern{$parameter};
        for my $val (@{$info->{$parameter}}) {
            unless ($val =~ m{$regexp}) {
                Carp::croak("$parameter invalid: $val\n");
            }
        }
    }

    ## optional parameters
    for my $key (qw/memory address/) {
        $info->{$key} = defined $info->{$key} ? $info->{$key} : '';
    }

    if ($self->{debug}) {
        printf STDERR "OK\n", $encoded_name;
    }
}

sub _create_docomo_data {
    my ($self, $info) = @_;

    my @params;

    my ($family_name, $first_name) = split /\s/, $info->{name1};
    my $name_param = join ',',  $family_name, $first_name;
    push @params, "MECARD:N:" . Encode::encode('shift_jis', $name_param);

    my ($family_kana, $first_kana) = map {
        _hankaku_to_zenkaku($_)
    } split /\s/, $info->{name2};
    my $sound_param = join ",", $family_kana, $first_kana;
    push @params, "SOUND:" . Encode::encode('shift_jis', $sound_param);

    for my $telephone (@{$info->{telephones}}) {
        $telephone =~ s{-}{}g;
        push @params, "TEL:" . $telephone;
    }

    for my $email (@{$info->{mail_addresses}}) {
        push @params, "EMAIL:" . $email;
    }

    my $note = $info->{memory};
    push @params, "NOTE:", Encode::encode('shift_jis', $note);

    my $data = join ';', @params;
    $data .= ';;';

    $data;
}

sub _create_au_data {
    my ($self, $info) = @_;

    # Specification of au is based on softbank one.
    my $data = $self->_create_softbank_data($info);

    # ADD(address)
    $data .= "ADD:" . Encode::encode('shift_jis', $info->{address});
    $data .= "\015\012";

    $data;
}

sub _create_softbank_data {
    my ($self, $info) = @_;
    my @params;

    my $memory = defined $info->{memory} ? $info->{memory} : '';
    push @params, "MEMORY:" . Encode::encode('shift_jis', $memory);

    (my $name1 = $info->{name1}) =~ s{\s}{}xms;
    push @params, "NAME1:" . Encode::encode('shift_jis', $name1);

    (my $name2 = $info->{name2}) =~ s{\s}{}xms;
    my $hankaku_name2 = _hankaku_to_zenkaku($name2);
    push @params, "NAME2:" . Encode::encode('shift_jis', $hankaku_name2);

    {
        my $i = 1;
        for my $mail_address (@{$info->{mail_addresses}}) {
            push @params, "MAIL${i}:" . $mail_address;
            $i++;
        }
    }

    {
        my $i = 1;
        for my $telephone (@{$info->{telephones}}) {
            $telephone =~ s{-}{}g;
            push @params, "TEL${i}:" . $telephone;
            $i++;
        }
    }

    my $data = join "\015\012", @params;

    $data .= "\015\012";
    $data;
}

sub _hankaku_to_zenkaku {
    my $zenkaku_str = shift;

    my $euc_str = Encode::encode('euc-jp', $zenkaku_str);
    Encode::JP::H2Z::z2h(\$euc_str);

    return Encode::decode('euc-jp', $euc_str);
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

1;
__END__

=encoding utf-8

=head1 NAME

QRCode::Carrier::JP -

=head1 SYNOPSIS

  use QRCode::Carrier::JP;

=head1 DESCRIPTION

QRCode::Carrier::JP is

=head1 AUTHOR

Syohei YOSHIDA E<lt>syohex@gmail.comE<gt>

=head1 SEE ALSO

=head1 LICENSE

Copyright 2011- Syohei YOSHIDA

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
