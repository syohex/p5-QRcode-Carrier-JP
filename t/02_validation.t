use strict;
use warnings;
use Test::More;

use QRCode::Carrier::JP;

my $app = QRCode::Carrier::JP->new();

# private method
can_ok($app, '_validate_contact_info');
can_ok($app, '_validate_contact_info_each');

done_testing;
