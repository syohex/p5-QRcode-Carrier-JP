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

is(scalar @contact_infos, 1, "return value length");

my $contact_info = $contact_infos[0];
isa_ok($contact_infos[0], "QRCode::Carrier::JP::ContactInfo");

can_ok($contact_info, "as_string");

my $str = $contact_info->as_string;

my $regexp;
$regexp = qr{
                名前:
                \s+
                山田 \s 太郎\(ヤマダ \s タロウ\)
}xms;
like $str, $regexp, "name part";

$regexp = qr{
                メールアドレス:
                \s+
                yamada_taro\@pc\.example\.com
}xms;
like $str, $regexp, "mail part";

$regexp = qr{
                電話番号:
                \s+
                09012345678 # remove '-' characters
}xms;
like $str, $regexp, "telephone part";

$regexp = qr{
                住所:
                \s+
                〇〇県〇〇市1-1
}xms;
like $str, $regexp, "address part";

$regexp = qr{
                メモ:
                \s+
                Twitter:yamada
}xms;
like $str, $regexp, "memory part";

can_ok($contact_info, "output_qrcode");
throws_ok { $contact_info->output_qrcode() }
    qr/Error not specify carrier/, "carrier is undef";

throws_ok { $contact_info->output_qrcode('att') }
    qr/Error invalid carrier/, "invalid carrier";

throws_ok { $contact_info->output_qrcode('docomo', undef) }
    qr/Output file is not specified/, "output file is undef";

can_ok($contact_info, "qrcode_as_base64");

my $base64;
$base64 = $contact_info->qrcode_as_base64('docomo');

ok($base64, "DoCoMo QR code as Base64");
$base64 = $contact_info->qrcode_as_base64('au');
ok($base64, "au QR code as Base64");

$base64 = $contact_info->qrcode_as_base64('softbank');
ok($base64, "SoftBank QR code as Base64");

throws_ok { $contact_info->qrcode_as_base64() }
    qr/Error not specify carrier/, "carrier is undef";

throws_ok { $contact_info->qrcode_as_base64('att') }
    qr/Error invalid carrier/, "invalid carrier";

can_ok($contact_info, "as_string");

done_testing;
