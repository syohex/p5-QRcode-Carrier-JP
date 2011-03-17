use inc::Module::Install;
use Module::Install::AuthorTests;
use Module::Install::ReadmeMarkdownFromPod;

name 'QRCode-Carrier-JP';
all_from 'lib/QRCode/Carrier/JP.pm';
readme_markdown_from('lib/QRCode/Carrier/JP.pm');

requires 'Imager::QRCode' => 0.033;
requires 'Class::Accessor::Lite' => 0.05;
requires 'Lingua::JA::Regular::Unicode';
requires 'MIME::Base64';

test_requires 'Test::More' => 0.88;

auto_set_repository();
WriteAll;
