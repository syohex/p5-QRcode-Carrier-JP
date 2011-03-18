use strict;
use warnings;

use Test::More;
use Test::Exception;

use QRCode::Carrier::JP;

use utf8;

binmode STDOUT, ":utf8";
binmode STDERR, ":utf8";

my $app = QRCode::Carrier::JP->new();
can_ok($app, 'run');

my @contact_infos = $app->run({
    id1 => {
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
    }
});

my $contact_info = $contact_infos[0];

my $docomo_data = $contact_info->qrcode->{docomo};
my $docomo_expected = join ';', (
    'MECARD:N:山田,太郎',
    'SOUND:ﾔﾏﾀﾞ,ﾀﾛｳ',
    'TEL:09012345678',
    'EMAIL:yamada_taro@pc.example.com',
    'NOTE:Twitter:yamada;;',
);

my $docomo_encoded = Encode::encode('shift_jis', $docomo_expected);
is($docomo_data, $docomo_encoded, "DoCoMo QR code data");

my $au_data = $contact_info->qrcode->{au};
my $au_expected = join "\r\n", (
    'MEMORY:Twitter:yamada',
    'NAME1:山田太郎',
    'NAME2:ﾔﾏﾀﾞﾀﾛｳ',
    'MAIL1:yamada_taro@pc.example.com',
    'TEL1:09012345678',
    'ADD:〇〇県〇〇市1-1',
);

$au_expected .= "\r\n";

my $au_encoded = Encode::encode('shift_jis', $au_expected);
is($au_data, $au_encoded, "au code data");

my $softbank_data = $contact_info->qrcode->{softbank};
my $softbank_expected = join "\015\012", (
    'MEMORY:Twitter:yamada',
    'NAME1:山田太郎',
    'NAME2:ﾔﾏﾀﾞﾀﾛｳ',
    'MAIL1:yamada_taro@pc.example.com',
    'TEL1:09012345678',
);

$softbank_expected .= "\015\012";

my $softbank_encoded = Encode::encode('shift_jis', $softbank_expected);
is($softbank_data, $softbank_encoded, "softbank code data");

done_testing;
