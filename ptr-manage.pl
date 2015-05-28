#!/usr/bin/perl
use strict;
use warnings;
use Getopt::Long;
use Pod::Usage;
#use Data::Dumper;

sub isThing;
sub debug;

my (%db, %fqdn);
my ($context, $help, $man);
my (@add, @del);

GetOptions
( 'add=s{1,}'   => \@add
, 'del=s{1,}'   => \@del
, 'help|?'      => \$help
, 'man'         => \$man
) or pod2usage(2);

pod2usage(1) if $help;
pod2usage(-exitval => 0, -verbose => 2) if $man;

while (<STDIN>) {
    if (/^\$ORIGIN\s+(.*?)\s*$/) {
        $context = $1;
        debug(2, "Context set to $context");
            if (exists $db{$context}) {
                debug(1, "$context already defined! Will append...");
            } else {
                $db{$context} = {};
                $fqdn{$context} = {};
            }
            next;
    }

    unless (/^\d(.*?)\.\s*$/) {
        # TODO: Anchor raw line to the line above it to keep "context"
        $db{$context}{-1} = () unless exists $db{$context}{-1};
        push @{ $db{$context}{-1} }, $_;
        debug(2, "Skipping raw line: $_");
        next;
    }

    chomp(my @fields = split);
    # Strip whitespace
    #@fields = map { join( , split( )) } @fields;

    debug(2, "During context $context: @fields");

    next if (
        isThing($context, $fields[3], \%fqdn) ||
        isThing($context, $fields[0], \%db)
    );

    $db{$context}{$fields[0]} = {};

    $db{$context}{$fields[0]}->{ZONE} = $fields[1];
    $db{$context}{$fields[0]}->{TYPE} = $fields[2];
    # Separate key for fqdn but map back to main record
    $fqdn{$context}{$fields[3]} = $fields[0];
    $db{$context}{$fields[0]}->{PTR} = $fields[3];
}

#print Dumper(\%db);
#print Dumper(\%fqdn);
debug(1, "Have " . keys(%db) . " entries\nRebuilding...");

# Sort keys
my @stack;
for (keys %db) {
    my @temp = map { local $_ = $_; s/[^\d]+//; $_ } split /\./;
    @temp = grep { $_ ne '' } @temp;
    push @stack, \@temp;
}

for my $KA (sort { @$a <=> @$b || @$a[0] <=> @$b[0] } @stack) {
    # I'm too lazy to do this properly
    my $key = join('.', @{$KA}) . '.in-addr.arpa.';

    # For each context:
    print "\$ORIGIN $key\n";
    for my $octet (sort { $a <=> $b || $a gt $b } keys %{ $db{$key} }) {
        if ($octet == -1) {
            print $_ for (@{ $db{$key}{$octet} });
            next;
        }

        my %param = %{$db{$key}{$octet}};
        printf("\t%i\t%s\t%s\t%s\n",
            $octet,
            $param{ZONE},
            $param{TYPE},
            $param{PTR}
        );
    }
}

sub isThing {
    my ($context, $field, $href, $line) = @_;
    my %hash = %$href;
    
    if (exists $hash{$context}{$field}) {
        debug(1, "[LINE: $.] $field already exists in $context");
        return 1;
    }

    return 0;
}

sub debug {
    my $lvl = ($_[0] =~ /\d+/) ? shift : 2;
    return unless $lvl == 1 || ($ENV{DEBUG} && $ENV{DEBUG} >= $lvl);
    my ($msg) = @_;
    my ($s,$m,$h) = ( localtime(time) )[0,1,2,3,6];
    my $date = sprintf "%02d:%02d:%02d", $h, $m, $s;
    warn "$date $msg", "\n";
}

__END__

=head1 ptr-manage

Manage named PTR files because apparently it's hard.

=head1 SYNOPSIS

ptr-manage
[ --add 127.0.0.1=example1.example.com [ ... ] ]
[ --del 127.0.0.1=example1.example.com [ ... ] ]
|| [ --man | --help ]

=head1 OPTIONS

=over 8

=item B<-help>

Print a brief help message and exit

=item B<-man>

Prints POD documentation and exits

=item B<-add>

Add PTR records in B<IP>=B<HOST> fashion. Additional entries can be added
separated by spaces. If the subnet does not exist it will be created
automatically as a new ORIGIN line.

=item B<-del>

Just like B<-add> only delete the records instead of add them.

=back

=head1 DESCRIPTION

B<ptr-manage> will read and write to STDIN/OUT while taking CLI arguments to
add or delete entries from the generated text. It can also be used to clean up
and sort existing databases whose maintainers were perhaps a little less than
diligent.

Part of the named-manage project.

=cut
