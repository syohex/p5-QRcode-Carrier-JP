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

my $tmpl_str = do {
    local $/;
    decode_utf8(scalar <DATA>);
};

my $tx = Text::Xslate->new(
    function => {
        newline_to_br_tag => sub {
            my $str = shift;
            $str =~ s{\n}{<br />}gxms;
            $str;
        },
    },
);
my $output_str = $tx->render_string($tmpl_str, {
    contact_infos => \@contact_infos,
    carriers      => [ qw/au docomo softbank/ ],
});
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
div.main { width: 1000px; margin: 0 auto 0 auto; text-align:center;}
table, td, th { border: 2px #808080 solid;}
table { margin: 0 auto 0 auto;}
th { font-family: sans-serif; font-size: 14px;}
td.contact_info { font-family:sans-serif; font-size:12px;
font-weight:700; text-align: left;}
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
: for $contact_infos -> $contact_info {
  <tr>
  <td class="contact_info">
      <: newline_to_br_tag($contact_info.as_string()) | mark_raw :>
  </td>
:  for $carriers.sort() -> $carrier {
      <td>
         <img src="data:image/png;base64,<: $contact_info.qrcode_as_base64($carrier) :>"
              alt="<: $carrier :>_QRcode" />
      </td>
:  }
  </tr>
: }
</table>
</div>
</body>
</html>
