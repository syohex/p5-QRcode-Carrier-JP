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

my $app = QRCode::Carrier::JP->new({debug => 0});

my $contact_info;
eval {
    $contact_info = do $input_file;
};
if ($@) {
    die "Error: read input file: $@\n";
}

my $qrcode_info = $app->run($contact_info);

my $png_base64 = {};
for my $name (%{$qrcode_info}) {
    my $qrcode_imager = $qrcode_info->{$name};

    for my $carrier (sort keys %{$qrcode_imager}) {
        my $png_data;
        $qrcode_imager->{$carrier}->write(
            data => \$png_data,
            type => 'png',
        );

        push @{$png_base64->{$name}}, encode_base64($png_data);
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
    },
);

print encode_utf8($output_str);

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
  width: 800px;
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

th.name-section {
  width: 100px;
  font-family: sans-serif;
  font-size: 14px;
}

td.name-section {
  width: 100px;
  font-family: sans-serif;
  font-size: 14px;
  font-weight: bold;
  text-align: center;
}
</style>

</head>

<body>
<div class="main">
<h1>キャリア別 QRコード</h1>
<table>
<tr>
  <th class="name-section">名前</th>
  <th>au</th>
  <th>docomo</th>
  <th>softbank</th>
</tr>

: for $png_base64.keys() -> $name {
  <tr>
  <td class="name-section"><: $name :></td>
:  for $png_base64[$name] -> $carrier_data {
      <td>
         <img src="data:image/png;base64,<: $carrier_data :>" />
      </td>
:  }
  </tr>
: }

</table>
</div>
</body>
</html>
