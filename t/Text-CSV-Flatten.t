use strict;
use warnings;

use Test::More tests => 17;
BEGIN { use_ok('Text::CSV::Flatten') };

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.
my $value= 42;
my $empty_data= {};
my $data= {
    calculus => {
        Newton => {
            birth => {
                year => 1642,
                month => 12,
            },
            death => {
                year => 1726,
                month => 3,
            },
            nationality => "English",
            apple => "yes",
        },
        Leibniz => {
            birth => {
                year => 1646,
                month => 6,
            },
            death => {
                year => 1716,
                month => 11,
            },
            nationality => "German",
            apple => "no",
        },
    },
};

is(Text::CSV::Flatten->new('.calculus.<name>.*.year', data=>$data)->csv . "\n", <<CSV);
birth,death,name
1642,1726,Newton
1646,1716,Leibniz
CSV

is(Text::CSV::Flatten->new('.calculus.*.<event>.year', data=>$data)->csv . "\n", <<CSV);
Leibniz,Newton,event
1646,1642,birth
1716,1726,death
CSV

is(Text::CSV::Flatten->new('.calculus.<name>.*.*', data=>$data)->csv . "\n", <<CSV);
birth_month,birth_year,death_month,death_year,name
12,1642,3,1726,Newton
6,1646,11,1716,Leibniz
CSV

is(Text::CSV::Flatten->new('.', data=>$value)->csv . "\n", <<CSV);
42
CSV

is(Text::CSV::Flatten->new('.', column_name=>"value", data=>$value)->csv . "\n", <<CSV);
value
42
CSV

is(Text::CSV::Flatten->new('.calculus.Newton.birth.year', data=>$data)->csv . "\n", <<CSV);
1642
CSV

is(Text::CSV::Flatten->new('.', data=>$empty_data)->csv . "\n", <<CSV);
{}
CSV

is(Text::CSV::Flatten->new('.nonexistent_key', data=>$empty_data)->csv, <<CSV);
CSV

is(Text::CSV::Flatten->new('.nonexistent_key', column_name=>"value", data=>$empty_data)->csv, <<CSV);
CSV

is(Text::CSV::Flatten->new('.nonexistent_key.nested', data=>$empty_data)->csv, <<CSV);
CSV

is(Text::CSV::Flatten->new('.calculus.Newton.<event>.<what>', column_name=>"value", data=>$data)->csv . "\n", <<CSV);
event,value,what
birth,1642,year
birth,12,month
death,1726,year
death,3,month
CSV

is(Text::CSV::Flatten->new('.calculus.Newton.<event>.year', column_name=>"year", data=>$data)->csv . "\n", <<CSV);
event,year
birth,1642
death,1726
CSV

is(Text::CSV::Flatten->new('.calculus.Newton.<event>.{year}', data=>$data)->csv . "\n", <<CSV);
event,year
birth,1642
death,1726
CSV

is(Text::CSV::Flatten->new('.calculus.{Newton,Leibniz}.birth.year', data=>$data)->csv . "\n", <<CSV);
Leibniz,Newton
1646,1642
CSV

is(Text::CSV::Flatten->new('.calculus.<who>.birth.{year} .calculus.<who>.birth.{month}', data=>$data)->csv . "\n", <<CSV);
month,who,year
12,Newton,1642
6,Leibniz,1646
CSV

is(Text::CSV::Flatten->new('.calculus.<who>.*.year .calculus.<who>.nationality .calculus.<who>.apple', column_name=>[qw/nationality apple/], data=>$data)->csv . "\n", <<CSV);
apple,birth,death,nationality,who
yes,1642,1726,English,Newton
no,1646,1716,German,Leibniz
CSV
