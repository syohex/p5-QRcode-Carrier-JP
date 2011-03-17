#!/usr/bin/env perl
use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../lib";

use QRCode::Carrier::JP;
use Text::Xslate;

use utf8;
use Encode;
use MIME::Base64;

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

my $qrcode_info = $app->run($contact_info);

my $png_base64 = {};
my $info_string = {};
for my $name (keys %{$qrcode_info}) {
    my $qrcode_imager = $qrcode_info->{$name};

    $info_string->{$name} = contact_info_as_string($contact_info->{$name});
    for my $carrier (sort keys %{$qrcode_imager}) {
        my $png_data;
        $qrcode_imager->{$carrier}->write(
            data => \$png_data,
            type => 'png',
        );

        $png_base64->{$name}->{$carrier} = encode_base64($png_data);
    }
}

my $tx = Text::Xslate->new(
    syntax => 'Kolon',
);

my $tmpl_str = do {
    local $/;
    my $str = <DATA>;
    decode_utf8($str);
};

my $output_str = $tx->render_string(
    $tmpl_str,
    {
        png_base64 => $png_base64,
        info_string => $info_string,
    },
);

print encode_utf8($output_str);

sub contact_info_as_string {
    my $contact_info = shift;

    my @attrs;

    push @attrs, "名前:";
    push @attrs, "<strong>" . $contact_info->{name1} .
        "(" . $contact_info->{name2} . ")</strong>";

    push @attrs, "メールアドレス:";
    push @attrs, $_ for @{$contact_info->{mail_addresses}};

    push @attrs, "電話番号:";
    push @attrs, $_ for @{$contact_info->{telephones}};

    if ($contact_info->{address}) {
        push @attrs, "住所:";
        push @attrs, $contact_info->{address};
    }

    if ($contact_info->{memory}) {
        push @attrs, "メモ:";
        push @attrs, $contact_info->{memory};
    }

    return join "<br />", @attrs;
}

__DATA__
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01//EN"
   "http://www.w3.org/TR/html4/strict.dtd">
<html lang="ja">
<head>
<meta http-equiv="Content-Type" content="text/html; charset=UTF-8" />
<meta http-equiv="Content-Style-Type" content="text/css" />
<title>キャリア別 QRコード</title>
<style type="text/css">
div.main {
  width: 900px;
  margin: 0 auto 0 auto;
  text-align:center;
}
table, td, th {
  border: 2px #808080 solid;
}
table {
  margin: 0 auto 0 auto;
}
th {
  font-family: sans-serif;
  font-size: 14px;
}
td.contact_info {
  font-family: sans-serif;
  font-size: 12px;
  text-align: left;
}
</style>
</head>

<body>
<div class="main">
<h1>キャリア別 QRコード</h1>
<table>
<tr>
  <th>連絡情報</th>
  <th>au</th>
  <th>docomo</th>
  <th>softbank</th>
</tr>

: for $png_base64.keys() -> $name {
  <tr>
  <td class="contact_info"><: $info_string[$name] | mark_raw :></td>
:  for $png_base64[$name].keys().sort() -> $carrier {
      <td>
         <img src="data:image/png;base64,<: $png_base64[$name][$carrier] :>"
              alt="<: $carrier :>_QRcode" />
      </td>
:  }
  </tr>
: }

</table>
</div>
</body>
</html>
