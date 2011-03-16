use strict;
use warnings;
use Test::More;

use QRCode::Carrier::JP;

my $app = QRCode::Carrier::JP->new({debug => 1,});
ok($app, "return not undef");
isa_ok($app, "QRCode::Carrier::JP");

is($app->{debug}, 1, "set debug parameter");

done_testing;
