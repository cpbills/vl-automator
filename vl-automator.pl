#!/usr/bin/perl

use strict;
use warnings;

use LWP;
use Getopt::Std;

# hashref to hold our options...
my $OPTS = {};

# get the options using Getopt::Std's exported 'getopts'
getopts('c:',$OPTS);

# this is a file containing url options / params to pass to the storm8 server
my $CONFIG = './config';
   $CONFIG = $$OPTS{c} if ($$OPTS{c});

my $config = read_config($CONFIG);
exit 1 unless ($config);

my $HOST    = $$config{host};
my $COOKIES = $$config{cookies};
my $HOME    = "http://$HOST/home.php";

my $browser = LWP::UserAgent->new;
$browser->cookie_jar( {} );
$browser->requests_redirectable( [ 'GET', 'POST', 'HEAD' ] );

my $html = &get_page($HOME);
my $info = &get_info($html);

foreach my $key (keys %$info) {
    print "$key: $$info{$key}\n";
}

while ($$info{frenzy} > 0) {
    &heal_thyself if ($$info{health} < 28);
    &fight_someone($html);
    $html = &get_page($HOME);
    $info = &get_info($html);
}

exit 0;

sub heal_thyself {
    my $result = &get_page("http://$HOST/hospital.php?action=heal");
}

sub fight_someone {
    my $html    =   shift;
    my ($fight_link) = ($html =~ /['"](\/fight\.php[^'"]*)/gis);
    my $fight_page = &get_page("http://${HOST}${fight_link}");
    my $fights = &process_fight_page("$fight_page");
    &fisher_yates_shuffle($fights);

    my $fight = pop(@$fights);
       $fight = "http://${HOST}/${fight}";
    my $fight_result = &get_page("$fight");
}

sub process_fight_page {
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

    if ($response->is_success) {
        return $response->content;
    } else {
        print STDERR "could not get $url -- ", $response->status_line, "\n";
        exit 1;
    }
    sleep 1;
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
