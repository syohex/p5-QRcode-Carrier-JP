use strict;
use warnings;

use Test::More;
use QRCode::Carrier::JP;

my $app = QRCode::Carrier::JP->new();
can_ok($app, 'run');

done_testing;
