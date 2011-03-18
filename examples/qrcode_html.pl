#!/usr/bin/env perl
use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../lib";

use QRCode::Carrier::JP;
use Text::Xslate;

use utf8;
use Encode;

my $input_file = shift or die "Usage $0 input_file\n";
die "$input_file is not found\n" unless -e $input_file;

my $app = QRCode::Carrier::JP->new();

my $contact_info;
eval {
    $contact_info = do $input_file;
};
if ($@) {
    die "Error: read input file: $@\n";
}

my @contact_infos = $app->run($contact_info);

my $tx = Text::Xslate->new(
    syntax => 'Kolon',
);

my $output_str = $tx->render('sample.tx', {
    contact_infos => \@contact_infos,
});
print encode_utf8($output_str);
