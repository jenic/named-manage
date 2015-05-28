use strict;
use warnings;

sub dbsort;

my @stack;
while (<>) {
    my @temp = map { local $_ = $_; s/[^\d]+//; $_ } split /\./;
    @temp = grep { $_ ne '' } @temp;
    push @stack, \@temp;
}

for ( sort { @$a <=> @$b || @$a[0] <=> @$b[0] } @stack ) {
    print join ':', @{$_}, "\n";
}

print "\n";

sub dbsort {
    #@{$stack[$a]} <=> @{$stack[$b]} || @{$stack[$a]}[0] <=> @{$stack[$b]}[0];
    @{$stack[$a]} <=> @{$stack[$b]};
}
