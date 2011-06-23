#!/usr/bin/perl

use strict;
use warnings;

use LWP;
use Getopt::Std;

# hashref to hold our options...
my $OPTS = {};

# get the options using Getopt::Std's exported 'getopts'
getopts('c:dva',$OPTS);

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

my $victims = read_config($$config{attack_history});

my $browser = LWP::UserAgent->new;
$browser->cookie_jar( {} );
$browser->requests_redirectable( [ 'GET', 'POST', 'HEAD' ] );

if ($$OPTS{a}) {
    # -a for ADD ... yeah... wait, not eh dee dee... like, attention
    # deficit di... what was i saying? oh, right add, for adding new people
    # to your clan... because i fuckin' automated that shit.
    # it goes through your comments, finds people's profiles, then goes through
    # their comments. it looks for 5-6 letter/number 'words' and tries using
    # them as clan codes. it takes a while to do, so i made it a flag...
    my @clan_codes = &traverse_profile_comments;
    foreach my $code (@clan_codes) {
        &invite_to_clan($code);
    }
}

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

&write_attack_history($$config{attack_history},$victims);

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

    # this block of code uses our attack history to attack an available target
    # who has been least attacked by us...
    my %enemy_hash = ();
    # looking for rivalId=[0-9]+
    foreach my $fight (@$fights) {
        my ($rivalid) = ($fight =~ /rivalId=([0-9]+)/i);
        $enemy_hash{$rivalid} = 0;
        $enemy_hash{$rivalid} = $$victims{$rivalid} if ($$victims{$rivalid});
    }
    my @targets = sort { $enemy_hash{$b} <=> $enemy_hash{$a} } keys %enemy_hash;
    my $target = pop(@targets);
    my ($fight) = grep { /rivalId=$target/i } @$fights;

    my $fight_result = &get_page("$BASE/$fight");
    print "$BASE/$fight\n" if ($DEBUG);

    if ($fight_result =~ /you won the fight/i) {
        $$victims{$target}++;
        return '#winning';
    }
    if ($fight_result =~ /cannot process your request/i) {
        return 'request failed';
    }
    if ($fight_result =~ /You lost the fight/i) {
        $$victims{$target}++;
        return 'defeated';
    }

    if ($DEBUG) {
        # this is sloppy and should be an option in the config, but...
        open FILE,'>>','/tmp/vampsfight.out';
        print FILE $fight_result,"\n";
        close FILE;
    }

    return 'unhandled';
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

sub write_attack_history {
    my $log     = shift;
    my $history = shift;

    if (open FILE,'>',$log) {
        foreach my $player (keys %$history) {
            print FILE "$player = $$history{$player}\n";
        }
        close FILE;
    } else {
        print STDERR "unable to write to $log: $!\n";
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

sub traverse_profile_comments {
    my $comments = "$BASE/ajax/getNewsFeedStories.php?selectedTab=comment";
    # first, fetch our comments
    my $html = &get_page($comments);
    # find any clan-code looking text in our comments section and init @codes
    my @codes = &find_clan_codes($html);
    # get links to all the people who've posted comments on our page
    my (@profiles) = ($html =~ /\/(profile.php[^'"]*)/gis);
    foreach my $profile (@profiles) {
        # for some reason, the extra data changes from grabbing the profile
        # to grabbing the comments; forcing us to hit storm8s server twice
        my $profile = &get_page("$BASE/$profile");
        if ($profile =~ /\/([^'"]*Tab=comment[^'"]*)/gis) {
            my $comments = $1;
            my $html = &get_page("$BASE/$comments");
            # push the newly found codes onto our array
            my @found = &find_clan_codes($html);
            push @codes, @found if (scalar @found > 0);
        }
    }
    return @codes;
}

sub invite_to_clan {
    my $code   =   shift;
    return unless $code;
    my $url = "$BASE/group.php?action=Invite&mobcode=$code";
    my $result = &get_page($url);
    if ($result =~ /<span class="success">Success!<\/span>/gi) {
        print "$code worked\n" if ($VERBOSE);
    } elsif ($result =~ /<span class="fail">Defeat:<\/span>/gi) {
        print "$code failed\n" if ($VERBOSE);
    } else {
        print "$code resulted in unknown response\n" if ($VERBOSE);
        print "$result\n" if ($DEBUG);
        exit if ($DEBUG);
    }
}

sub read_clan_codes {
    my %clan_codes = ();
    my $file = $$config{clan_codes};

    if ($file && -r $file) {
        if (open CLAN_CODES,'<',$file) {
            while (<CLAN_CODES>) {
                my $old_code = $_;
                chomp($old_code);
                $clan_codes{$old_code} = 1;
            }
            close CLAN_CODES;
        } else {
            print "failed to open $file: $!\n" if ($DEBUG);
        }
    } else {
        print "could not open clan_code file, check config\n" if ($DEBUG);
    }
    return \%clan_codes;
}

sub write_clan_codes {
    my $clan_codes  =   shift;
    my $file        =   $$config{clan_codes};

    if ($file) {
        if (open CLAN_CODES,'>>',$file) {
            foreach my $code (keys %$clan_codes) {
                print CLAN_CODES "$code\n";
            }
            close CLAN_CODES;
        } else {
            print "failed to open $file: $!\n" if ($DEBUG);
        }
    } else {
        print "could not open clan_code file, check config\n" if ($DEBUG);
    }
}

sub find_clan_codes {
    # this finds all 5-6 letter words in a page, compares against the history
    # and returns an array of untried 'codes'
    my $html =   shift;

    my $old_codes = &read_clan_codes;
    my $new_codes = {};

    my (@codes) = ($html =~ /\W(\w{5,6})\W/gis);
    foreach my $code (@codes) {
        $code = lc($code);
        unless ($$old_codes{$code}) {
            $$new_codes{$code} = 1;
        }
    }
    &write_clan_codes($new_codes);
    if (scalar(keys %$new_codes) > 0) {
        return keys %$new_codes;
    }
    return undef;
}
