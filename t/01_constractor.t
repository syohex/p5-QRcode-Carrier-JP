use strict;
use warnings;
use Test::More;

use utf8;
use QRCode::Carrier::JP;

my $app = QRCode::Carrier::JP->new();
ok($app, "QRCode::Carrier::JP->new don't return undef");
isa_ok($app, "QRCode::Carrier::JP");

my $contact_info = QRCode::Carrier::JP::ContactInfo->new({
    memory => 'Twitter:yamada',
    name1  => '山田 太郎',
    name2  => 'ヤマダ タロウ',
    mail_addresses => [
        'yamada_taro@pc.example.com',
    ],
    telephones => [
        '090-1234-5678',
    ],
    address => '〇〇県〇〇市1-1',
});
ok($contact_info, "QRCode::Carrier::JP::ContactInfo->new don't return undef");
isa_ok($contact_info, "QRCode::Carrier::JP::ContactInfo");

is($contact_info->birth, 0, "default birth");
is($contact_info->name1, '山田 太郎', "set KANJI name(name1)");
is($contact_info->name2, 'ヤマダ タロウ', "set KATAKANA name(name2)");
is($contact_info->mail_addresses->[0], 'yamada_taro@pc.example.com', "set mail address");
is($contact_info->telephones->[0], '090-1234-5678', "set telephone number");
is($contact_info->address, '〇〇県〇〇市1-1', "set address");

done_testing;
