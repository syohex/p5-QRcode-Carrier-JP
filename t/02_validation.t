use strict;
use warnings;
use Test::More;
use Test::Exception;
use Storable qw/dclone/;

use utf8;
use QRCode::Carrier::JP::ContactInfo;

my $contact_info = QRCode::Carrier::JP::ContactInfo->new({
    id => 'id1',
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

can_ok($contact_info, 'validate');

{
    my $invalid = dclone($contact_info);
    $invalid->name1('山田太郎');
    throws_ok { $invalid->validate }
        qr/separate family name and first name with a space/, 'no space';

    $invalid->name1('山田 太郎' . 'あ' x 8);
    lives_ok { $invalid->validate } 'valid name1 length(<= 24byte)';

    $invalid->name1('山田 太郎' . 'あ' x 9);
    throws_ok { $invalid->validate }
        qr/is too long/, 'too long name1(> 24byte)';
}

{
    my $invalid = dclone($contact_info);
    $invalid->name2('ヤマダタロウ');
    throws_ok { $invalid->validate }
        qr/separate family name and first name with a space/, 'no space';

    $invalid->name2('やまだ たろう');
    throws_ok { $invalid->validate }
        qr/must consist of KATAKANA/, 'not KATAKANA';

    $invalid->name2('ヤマタ タロウ' . 'ウ' x 18);
    lives_ok { $invalid->validate } 'valid name2 length(<= 24byte)';

    $invalid->name2('ヤマタ タロウ' . 'ウ' x 19);
    throws_ok { $invalid->validate }
        qr/is too long/, 'too long name(> 24byte)';
}

{
    my $invalid = dclone($contact_info);
    $invalid->mail_addresses([
        'a@a', 'b@b', 'c@c', 'd@d',
    ]);
    throws_ok { $invalid->validate }
        qr/must be less than equal 3/, 'mail addresses are too much';

    $invalid->mail_addresses([
        'aaaaaa'
    ]);
    throws_ok { $invalid->validate }
        qr/mail_addresses invalid/, 'not much mail format';

    $invalid->mail_addresses([
        'a@' . 'a' x 58,
    ]);
    lives_ok { $invalid->validate } 'valid mail address length(<= 60byte)';

    $invalid->mail_addresses([
        'a@' . 'a' x 59,
    ]);
    throws_ok { $invalid->validate }
        qr/is too long/, 'too long mail address(> 60byte)';
}

{
    my $invalid = dclone($contact_info);
    $invalid->telephones([
        1111, 2222, 3333, 4444,
    ]);
    throws_ok { $invalid->validate }
        qr/must be less than equal 3/, 'telephone numbers are too much';

    $invalid->telephones([
        'invalid-telephone'
    ]);

    throws_ok { $invalid->validate }
        qr/telephones invalid/, 'not much telephone format';

    $invalid->telephones([
        '0' x 24,
    ]);
    lives_ok { $invalid->validate } 'valid telephone length(<= 24byte)';

    $invalid->telephones([
        '0' x 25,
    ]);
    throws_ok { $invalid->validate }
        qr/is too long/, 'too long telephone number(> 24byte)';
}

{
    my $invalid = dclone($contact_info);
    $invalid->address( 'a' x 80 );
    lives_ok { $invalid->validate } 'valid memory length(<= 80byte)';

    $invalid->memory( "a" x 81 );
    throws_ok { $invalid->validate }
        qr/is too long/, 'memory length too long(> 80byte)';
}

{
    my $invalid = dclone($contact_info);
    $invalid->address( 'a' x 80 );
    lives_ok { $invalid->validate } 'valid address length(<= 80byte)';

    $invalid->address( 'a' x 81 );
    throws_ok { $invalid->validate }
        qr/is too long/, 'too long address(> 80byte)';
}

done_testing;
