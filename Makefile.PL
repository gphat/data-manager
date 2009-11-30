use inc::Module::Install;

name     'Data-Manager';
all_from 'lib/Data/Manager.pm';
author   q{Cory G Watson <gphat@cpan.org>};
license  'perl';

build_requires 'Test::More';

requires 'Data::Verifier' => '0.23';
requires 'Message::Stack' => '0.11';
requires 'MooseX::Storage';
requires 'JSON::Any';

WriteAll;

