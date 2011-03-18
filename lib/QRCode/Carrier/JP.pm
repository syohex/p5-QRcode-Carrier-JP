package QRCode::Carrier::JP;
use strict;
use warnings;

use 5.008_001;
our $VERSION = '0.02';

use Carp ();
use Encode ();

use QRCode::Carrier::JP::ContactInfo;

use constant DEBUG => defined $ENV{QRCODE_DEBUG};
our $ENCODE_CHARSET = 'utf-8';

sub new {
    my ($class, $args) = @_;
    bless {}, $class;
}

sub run {
    my ($self, $args) = @_;

    unless (ref $args eq "HASH") {
        Carp::croak("Argument must be HASH reference\n");
    }

    my @contact_infos;
    while (my ($id, $info) = each %{$args}) {
        my $contact_info = QRCode::Carrier::JP::ContactInfo->new($info);

        if (DEBUG) {
            Carp::carp("Validate ", Encode::encode($ENCODE_CHARSET, $id), "\n");
        }
        $contact_info->validate;

        $contact_info->create_qr_code();

        push @contact_infos, $contact_info;
    }

    return @contact_infos;
}

1;
__END__

=encoding utf-8

=head1 NAME

QRCode::Carrier::JP - QRCode Generator

=head1 SYNOPSIS

  use QRCode::Carrier::JP;

=head1 DESCRIPTION

QRCode::Carrier::JP is

=head1 INTERFACE

=head2 Class Methods

=head3 C<< QRCode::Carrier::JP->new(\%args) >>

Create and returns a new QRCode::Carrier::JP instance.
Arguments should be HASH reference.

I<\%args> might be;

=over

=item debug :Int

Output debug message to STDERR.

=back

=head3 C<< QRCode::Carrier::JP->run(\%contact_info) >>

Argument should be HASH reference.

I<%args> might be the follwing format:

$contact_info = {
    'your_name' => {
        # Set information which you like (<= 80byte as Shift_jis)
        memory => 'memo',

        # Set KANJI name.(<= 24byte as Shift_jis)
        # Family and first name should be separated with a space.
        name1  => 'your KANJI name',

        # Set KATAKANA name.(<= 24byte as Shift_jis)
        # Family and first name should be separated with a space.
        name2  => 'your KATAKANA name',

        # Set mail addresses as ARRAY reference. (<= 60byte as Ascii)
        # Array length should be less than equal 3.
        mail_addresses => [
            'your first mail address',
            'your second mail address',
        ],

        # Set mail addresses as ARRAY reference. (<= 60byte as Ascii)
        # Array length should be less than equal 3.
        telephones => [
            'your first telephone number',
            'your first second number',
        ],

        # Set address where you live. (<= 80byte as Shift_jis)
        address => 'your_address',

        # year of birthday(default is 0)
        # This parameter is free attribute, I use it for sorting.
        birth => 'your birth year',
     },

    'his_name' => {
        .....
     },
     .....
};

Return valus is array of QRCode::Carrier::JP::ContactInfo instances.

=head1 AUTHOR

Syohei YOSHIDA E<lt>syohex@gmail.comE<gt>

=head1 SEE ALSO

C<QRCode::Carrier::JP::ContactInfo>, C<Imager::QRCode>

=head1 LICENSE

Copyright 2011- Syohei YOSHIDA

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
