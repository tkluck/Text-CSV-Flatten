use strict;
use warnings;

use Test::More tests => 4;
BEGIN { use_ok('Text::CSV::Flatten') };

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.
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
        },
    },
};

is(Text::CSV::Flatten->new(pattern=>'calculus.<name>.*.year', data=>$data)->csv . "\n", <<CSV);
birth,death,name
1646,1716,Leibniz
1642,1726,Newton
CSV

is(Text::CSV::Flatten->new(pattern=>'calculus.*.<event>.year', data=>$data)->csv . "\n", <<CSV);
Leibniz,Newton,event
1646,1642,birth
1716,1726,death
CSV

is(Text::CSV::Flatten->new(pattern=>'calculus.<name>.*.*', data=>$data)->csv . "\n", <<CSV);
birth_month,birth_year,death_month,death_year,name
6,1646,11,1716,Leibniz
12,1642,3,1726,Newton
CSV
