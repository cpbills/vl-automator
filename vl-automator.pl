#!/usr/bin/perl

use strict;
use warnings;

use LWP;
use Getopt::Std;

# hashref to hold our options...
my $OPTS = {};

# get the options using Getopt::Std's exported 'getopts'
getopts('c:dv',$OPTS);

# this is a file containing url options / params to pass to the storm8 server
my $CONFIG = './config';
   $CONFIG = $$OPTS{c} if ($$OPTS{c});

my $DEBUG   = 0;
   $DEBUG   = 1 if ($$OPTS{d});

my $VERBOSE = 0;
   $VERBOSE = 1 if ($$OPTS{v});

my $config = read_config($CONFIG);
exit 1 unless ($config);

my $COOKIES = $$config{cookies};
my $BASE    = $$config{base};
my $HOME    = "$BASE/home.php";

my $browser = LWP::UserAgent->new;
$browser->cookie_jar( {} );
$browser->requests_redirectable( [ 'GET', 'POST', 'HEAD' ] );

my $html = &get_page($HOME);
my $info = &get_info($html);

while ($$info{frenzy} > 0 || $$info{energy} >= $$config{mission_energy}) {
    if ($DEBUG) {
        foreach my $key (keys %$info) {
            print "$key: $$info{$key}\n";
        }
    }
    if ($$info{frenzy} > 0) {
        if ($$info{health} < 28) {
            print "healing myself!\n" if ($VERBOSE);
            &heal_thyself;
        }
        print "attempting to beat someone up! " if ($VERBOSE);
        my $result = &fight_someone;
        print "$result\n" if ($VERBOSE);
    } elsif ($$info{energy} >= $$config{mission_energy}) {
        print "doing a mission!\n" if ($VERBOSE);
        &do_a_mission($$config{mission_page},$$config{mission_jid});
    }
    $html = &get_page($HOME);
    $info = &get_info($html);
}

exit 0;

sub heal_thyself {
    my $result = &get_page("$BASE/hospital.php?action=heal");
}

sub do_a_mission {
    # best mission, currently, is 'eliminate straggling cubs'
    # in the downtown mission block, 12 energy for 14 experience
    # 1.166666 : 1 ... not bad. 'jid' is 97
    my $cat     =   shift;
    my $jid     =   shift;

    my $page = &get_page("$BASE/$cat");
    my $missions = &extract_links($page);
    foreach my $mission (@$missions) {
        my $result = &get_page("$BASE/$mission") if ($mission =~ /jid=$jid/);
    }
}

sub fight_someone {
    my $fight_page = &get_page("$BASE/fight.php");
    my $fights = &extract_links("$fight_page");
    &fisher_yates_shuffle($fights);

    my $fight = pop(@$fights);

    my $fight_result = &get_page("$BASE/$fight");
    print "$BASE/$fight\n" if ($DEBUG);
    if ($fight_result =~ /you won the fight/i) {
        return '#winning';
    }
    if ($fight_result =~ /cannot process your request/i) {
        return "request failed\n$fight";
    }
    return 'defeated';
}

sub extract_links {
    # this function is /really/ sloppy, and therefore prone to breaking...
    my $source  = shift;

    my %bs = ();
    my %ps = ();
    my %xs = ();

    my $current_func = '';
    foreach my $line (split(/\n/,$source)) {
        # look for 'function jkhdaskjd(x)' on a line; when we find it
        # jkhdaskjd becomes our current function. then we store the arrays
        # a and p for later calculation...
        if ($line =~ /function ([^(]*)\(x\)/) {
            $current_func = $1;
        }
        if ($line =~ /var b=new Array\(([^)]*)\)/) {
            my @array = split(/,/,$1);
            $bs{$current_func} = \@array;
        }
        if ($line =~ /var p=new Array\(([^)]*)\)/) {
            my @array = split(/,/,$1);
            $ps{$current_func} = \@array;
        }
        if ($line =~ /return $current_func\(['"]([^'"]*)/) {
            $xs{$current_func} = $1;
        }
    }
    my @links = ();
    foreach my $key (keys %xs) {
        # replicating: 'window.location c(b,p) + x'
        #function c(b,p) {
        #    a='';s=String.fromCharCode;
        #    for(i=0;i<b.length;i++) {if(p[i])a=s(b[i])+a;else a+=s(b[i]);}
        #    return a;
        #}
        push @links, &decrypt_link($xs{$key},$bs{$key},$ps{$key});
    }
    return \@links;
}

sub decrypt_link {
    # replicating: 'window.location c(b,p) + x'
    #function c(b,p) {
    #    a='';s=String.fromCharCode;
    #    for(i=0;i<b.length;i++) {if(p[i])a=s(b[i])+a;else a+=s(b[i]);}
    #    return a;
    #}
    my $x   = shift;
    my $b   = shift;
    my $p   = shift;

    my @B   = @$b;
    my @P   = @$p;

    my $string = '';
    for my $i (0 .. $#B) {
        if ($P[$i] == 0) {
            $string = $string . chr($B[$i]);
        } else {
            $string = chr($B[$i]) . $string;
        }
    }
    $string .= $x;
    return $string;
}

sub fisher_yates_shuffle {
    my $array = shift;
    my $i;
    return if (@$array < 2);
    for ($i = @$array; --$i; ) {
        my $j = int rand ($i+1);
        next if $i == $j;
        @$array[$i,$j] = @$array[$j,$i];
    }
}

sub get_info {
    my $html    =   shift;

    my ($energy) = ($html =~ /nergyCurrent" class="statEmphasis">([0-9]+)/gis);
    my ($health) = ($html =~ /ealthCurrent" class="statEmphasis">([0-9]+)/gis);
    my ($frenzy) = ($html =~ /aminaCurrent" class="statEmphasis">([0-9]+)/gis);

    return { energy => $energy, health => $health, frenzy => $frenzy };
}

sub get_page {
    my $url         =   shift;

    my $response = $browser->get("$url", Cookie => "$COOKIES");
    sleep 1;

    if ($response->is_success) {
        return $response->content;
    } else {
        print STDERR "could not get $url -- ", $response->status_line, "\n";
        exit 1;
    }
}

sub read_config {
    my $conf_file = shift;

    my %options = ();
    if (open FILE,'<',$conf_file) {
        while (<FILE>) {
            my $line = $_;
            next if ($line =~ /^\s*$/);
            next if ($line =~ /^\s*#/);
            $line =~ s/^\s*//;
            $line =~ s/\s*$//;
            my ($opt,$val) = split(/\s+=\s+/,$line);
            $options{$opt} = $val;
        }
        close FILE;
    } else {
        print STDERR "unable to open $conf_file: $!\n";
        return undef;
    }
    return \%options;
}
