#!/usr/bin/perl

use strict;
use warnings;

use LWP::UserAgent;
use Getopt::Std;

# hashref to hold our options...
my $OPTS = {};

# get the options using Getopt::Std's exported 'getopts'
getopts('c:h:',$OPTS);

# this file contains the cookies for signing in.
my $COOKIES = "./storm8-vl.cookies";
   $COOKIES = $$OPTS{c} if ($$OPTS{c});

# this is the http host we will connect to.
my $HOST = 'vl.storm8.com';
   $HOST = $$OPTS{h} if ($$OPTS{h});

my $vl_cookies = read_cookies($COOKIES);
exit 1 unless ($vl_cookies);

my $browser = LWP::UserAgent->new;
$browser->default_header('Cookie',$vl_cookies);


exit 0;


sub read_cookies {
    my $cookie_file = shift;

    if (open FILE,'<',$cookie_file) {
        my $cookies = (<FILE>);
        chomp($cookies); # yummy!
    } else {
        print STDERR "could not open $cookie_file: $!\n";
        return undef;
    }
    return $cookies;
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
            my ($opt,$val) = split(/\s*=\s*/,$line);
            $options{$opt} = $val;
        }
        close FILE;
    } else {
        print STDERR "unable to open $conf_file: $!\n";
        return undef;
    }
    return \%options;
}
