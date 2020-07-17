use POSIX;

################################# GLOBAL VARIABLES ##################################
my $sl = qr/\s|\\qquad|\\quad|\\ |\\:|\\,|\\;|\\!/; # latex whitespace
my $slindent = qr/\\qquad|\\quad|\\ |\\:|\\,|\\;/; # latex indent whitespace
my $cmpl = qr/(?:\\overset(?:\S|\{.*\}|\\[a-z]+))?(?:=|>|<|(?:\\approx|\\equiv|\\nsim|\\sim|\\ngtr|\\nless|\\ngeq|\\geq|\\ge|\\nleq|\\leq|\\le|\\neq|\\ne|\\propto
    |\\rhd|\\lhd|\\unrhd|\\unlhd|\\ll|\\gg|\\doteq|\\simeq|\\subseteq|\\subset|\\supseteq|\\supset|\\ncong|\\cong)(?![a-zA-Z])
    |\\not(?:=|>|<)|\\not(?:\\leq|\\le|\\geq|\\ge|\\sim|\\approx|\\cong|\\equiv)(?![a-zA-Z]))/x; # latex comperator (still not exhaustive!)
my $notlatexdollar = qr/\\.|[^\\\$]/s;
my $notlatexquotedstart = qr/^(?:(?:$notlatexdollar*\$){2})*/;
my $notlatexquoted = qr/${notlatexquotedstart}$notlatexdollar*/; # i'm debating whether or not to include the ^ in here
my $latexquoted = qr/^(?:$notlatexdollar*\$)(?:(?:$notlatexdollar*\$){2})*$notlatexdollar*/;
my $num = qr/-?(?<![\d\.])\d+(?!]])(?:,\d{3})*(?:\.\d+)?(?!\d)/;

my $domain = qr/\w|TxM|TvM|TM|\\?R^?[nm]/;
my $blankline = qr/(?:[^\n\S]*\n)/;

#####################################################################################
sub latexquote{
    my ($q) = @_;
        $q =~ s#"(.*?)"#``$1''#g;
    return $q;
}

# START OF IF/ELSEIF STATEMENTS:
#===============================

if (0) {
    # just a dummy statement, so that ALL others can be 'elseif', for consistency, and to prevent accidentally deleting the 'if' here.
}

# KHAN ACADEMY REGULAR EXPRESSIONS:
#==================================

# perhaps rename to MATHY
# for now this only finds lone numbers and %s and wraps them
elsif( $c =~ /^(?:mathify|latexify)(?:\s+(SPR))?$/i ){
    my $SPR = $1;
    # we want the WHOLE number, so we look back/forward for NOT \d
    # $num is defined globally
    # not latex quoted is greedy, which can make $num act reluctant even though it is not designed that way :(
    while( $q =~ s@($notlatexquoted)($num)(st|nd|rd|th)(?![\w/])@  $1 . '$' . &commafy($2) . "^\\text{$3}". '$' @eg ){} # numbers ending in st,nd,rd,th
    while( $q =~ s|($notlatexquoted)(\\\$$num)|                    $1 . '$' . &commafy($2)                . '$' |eg ){} # money amounts
    while( $q =~ s@($notlatexquoted)(?<![\w/])($num)((?:\\?%)?)(?![\w/])@ $1 . '$' . &commafy($2) . '\\%' x!! $3 . '$' @eg ){} # numbers not in fractions
    while( $q =~ s|($notlatexquoted)($num)/($num)|                 $1 . '$' . '\\dfrac{' . &commafy($2) .'}{' . &commafy($3) . '}' . '$' |eg ){} # numbers in fractions

    sub commafy{
        my ($num) = @_;
        # $num = ceil($num*10) / 10; # when you want to round!
        if( $SPR and 0 <= $num and $num < 10000 ){ return $num } # consider adding SPR support later w/ a global SPR variable at top of this file
        my $separator = "{,}";
        my @parts = split(/\./, $num); # split ALWAYS takes in first parameter as Regex, even if you supply it as normal quoted string!
        $parts[0] =~ s/\B(?=(\d{3})+(?!\d))/$separator/g; # \B is a NON word boundary
        return join('.', @parts);
    }

}

#remove unecessary period after abbreviations
elsif( $c =~ /^(abbr|remove)$/ ){
    $q =~ s/(in|mi|ft|yd|km)\./$1/g;
}

# erases cancelled things!
elsif( $c =~ /^cancelcancel|ccancel|cc$/ ){ # ORDER MATTERS.  THIS GOES BEFORE cancelunits
    $q =~ s/\\cancel(\{[^{}]*(?1)?[^{}]*\}|\d)//xg; # uses recursive regex bracket inception
}

# finds units or variables or numbers and cancels them!
elsif( $c =~ /(?:cancel|cancel\s*units?)\s*((?:blue|green|pink|red|purple|gray)?)\s+(.+)/ ){
    my ( $color, $unit, $regex ) = ( $1, quotemeta($2), $2 );
    $q =~  s|\\text\{$unit\}(?:\^\d+)?| "\\$color\{" x!! $color . "\\cancel{$&}" . '}' x!! $color |eg # for text-wrapped quoted unit
        or
    $q =~            s|$unit(?:\^\d+)?| "\\$color\{" x!! $color . "\\cancel{$&}" . '}' x!! $color |eg # for non text-wrapped quoted unit
        or
    $q =~ s|\\text\{$regex\}(?:\^\d+)?| "\\$color\{" x!! $color . "\\cancel{$&}" . '}' x!! $color |eg # for text-wrapped regex unit
        or
    $q =~           s|$regex(?:\^\d+)?| "\\$color\{" x!! $color . "\\cancel{$&}" . '}' x!! $color |eg # for non text-wrapped regex unit
}

# erases empty latex tags
elsif( $c =~ /^empty$/ ){
    # while means that it runs over and over until there are no more
    my @left = ( qr/\(/, qr/\\left\(/, qr/\\left\[/, qr/\\left\\\{/ );
    my @right = ( qr/\)/, qr/\\right\)/, qr/\\right\]/, qr/\\right\\\}/ );
    my $emptypairs; for my $i (0..$#left){ $emptypairs .= "$left[$i]\\s*$right[$i]|" } $emptypairs = substr( $emptypairs, 0, -1 );
    #my $emptypairs = qr/  \(\s*\)  |  \\left\(\s*\\right\)  |  \\left\[\s*\\right\]  |  \\left\\\{\s*\\right\\\}  /x;
    while( $q =~ s/  (\\\w+|\^|_)?\s*{\s*}   |   $emptypairs  //oxg )
    # and hanging, +, -, \cdot, \times, \pm
    {
        my $operation = qr/\+|-|\\cdot|\\times|\\pm|\\,|\\:|\\;|\\!/;
        my $left = "(?'left'" . '^|' . join( '|', @left ) . ')';
        my $right = "(?'right'" . '$|' . join( '|', @right ) . ')';

        # NO.  ITS BETTER TO REMOVE HANGING THINGS when you remove the cancel.  just look to the left and right!

        #$q =~ s/ $left\s*$operation | $operation\s*$right //oxg
    }
    # what about 5 * 4 + 2
}

#For LaTeX cleaning:
#------------------

elsif( $c =~ /^(?:no|fix)?\s*spaces$/ ){
    #converting 5\cdot\text{ miles} to 5\cdot\text{miles} for better cancellations:
    $q =~ s/(\\cdot)\s*((?:\\(?:blue|green|pink|red|purple|gray)\{)?\s*(?:\\cancel\{)?\s*\\text\s*\{)\s+/$1$2/g;
    #converting 5\text{ miles} to 5\,\text{miles} for better cancellations:
    $q =~ s/([^\s{])\s*((?:\\(?:blue|green|pink|red|purple|gray)\{)?\s*(?:\\cancel\{)?\s*\\text\s*\{)\s+/$1\\,$2/g;
    #converting \text{5 miles} to 5\,\text{miles}
    $q =~ s/\\text\s*\{(\d+)\s+/$1\\,\\text{/g;
    #converting stuff like \:\text{stuff} to \,\text{stuff}
    $q =~ s/(?:\\ |\\;|\\:)\s*\\text/\\,\\text/g;
}

# stuff like $x$-intercept is given a non-breaking hypen.  In general, $latex$-word is given a non-breaking hyphen.
elsif( $c =~ /^dashes$/ ){
    while( $q =~ s/($notlatexquotedstart)-(\w+)/$1‑$2/ ){}
}

#converting paragraphed equation steps into latex begin{align} steps
elsif( $c =~ /^combine\s*(paragraphs)?$/ ){
    $q =~ s/((?:^|\n)\s*)\$$notlatexdollar+\$(?:\s*\n\s*\$$notlatexdollar+\$)*(?=\s*(?:\n|$))/$1.&combine($&)/eg;

    sub combine{
        my ($q) = @_;
            $q =~ s/\s*\$\s*\$\s*/ \\\\\n\\\\\n/g; # $'s separate equations and are replaced with \\ newline \\ newline
            $q =~ s/(?:^|\n)\s*\$\s*/\$\n\\begin{align}\n/g; # the very first dollar is replaced with $\begin{align} newline
            $q =~ s/\s*\$\s*($|\n)\s*(?!\s*\\begin)/\n\\end{align}\n\$/g; # last dollar replaced with \end{align}$
            # if there is NO EQUALS or APPROX whatsoever in the first line, then we put the & at the beginning of first line (w/ \quad for proper spacing)
            $q =~ s/  (?<=\\begin{align}\n)    (?=(?:(?!$cmpl).)*\\\\)  /&\\quad /x;
            $q =~ s/$cmpl(?!\$\s*\\begin)/&$&/g; # for all lines w/ = or other comperator, we align to it
        return $q
    }
}

elsif( $c =~ /^comment$/ ){
    $q =~ s|^(.*?)$|[//]: # ($1 )|mg;
}

elsif( $c =~ /^uncomment$/ ){
    $q =~ s|^[^\S\n]*\[//\]:\s+#\s+\((.*?) ?\)$|$1|mg;
}

elsif( $c =~ /^paren$/ ){
    $q =~ s!\( *\$(?:\\,)?((?:\\.|[^\$])+?)(?:\\,)?\$ *\)!\$\\left($1\\right)\$!g;
}

elsif( $c =~ /^noparen$/ ){
    $q =~ s!(?:\\left|\\right)(?:\(|\)|\[|\])!!g;
}

elsif( $c =~ /^caps?$/ or $c =~ /^upper(?:case)?$/ ){
    $q =~ tr[a-z][A-Z];
}

elsif( $c =~ /^low(?:er(?:case)?)?$/ ){
    $q =~ tr[A-Z][a-z];
}

elsif( $c =~ /^unindent$/ ){
    $q =~ s/$slindent//g;
}

elsif( $c =~ /^pointify$/ ){
    $q =~ s/($num)[^\S\n]+(?=$num)/$1, /g;
    $q =~ s/^(.*)$/\t[$1],/mg;
}

elsif( $c =~ /^everyother$/ ){
    $q =~ s/\[\d\.\d+e\+\d, \d\.\d+e\+\d\],\n(\[\d\.\d+e\+\d, \d\.\d+e\+\d\],)/$1/g;
}

elsif( $c =~ /^quote$/ ){
    $q =~ s/^.*$/'$&',/mg;
}

elsif( $c =~ /^commafy$/ ){
#   $q =~ s/(?:^|\n)(.+)/ $1,/g;
    $q =~ s/($num)\s+/$1, /g;
}

elsif( $c =~ /^triangle$/ ){
    $q =~ s@\$\\triangle@triangle\ \$@g;
}

elsif( $c =~ /^tabify$/ ){
    $q =~ s/    /\t/g;
}

elsif( $c =~ /^bullets?$/ ){
    $q =~ s!\$\\bullet\$!\ \ \*\ !g;
}

elsif( $c =~ /^functionify$/ ){
    $q =~ s/\\(sin|cos|tan|sec|csc|arcsin|arccos|arctan)\s*(\\?\w+)/\\$1($2)/g;
}


elsif( $c =~ /^pluckpoints$/ ){
    $q =~ s/.*\[\s*(-?\d+(?:\.\d+)?)\s*,\s*(-?\d+(?:\.\d+)?)\s*\].*/\t[$1, $2],/mg;
}

elsif( $c =~ /^addtemplate$/ ){
    $q =~ s|^.*$|Perseus:\nlink\n\nProject tracker:\n$&\n\nLink to Trello cards:\n- Group 1:\nlink\n- Group 2:\nlink\n\nReview docs:\nlink|mg;
}

elsif( $c =~ /^(?:m(?:ark)?d(?:own)?)?indent$/ ){
    $q =~ s/^/    /mg;
}

elsif( $c =~ /^code$/ ){
    $q =~ s/^/    /mg;
    # delete any trailing newlines
    $q =~ s/\n*$//;
    # wrap in code tags
    $q = '{code:javascript}'."\n".$q."\n".'{code}';
    # append a final newline
    $q = $q."\n";
}

elsif( $c =~ /^arrayify$/ ){
    $q =~ s/\\begin{align}/\\begin{array}{ccccc}/;
    $q =~ s/\\end{align}/\\end{array}/;
    $q =~ s/$slindent//g;
    $q =~ s/&?\s*($cmpl)\s*&?/& $1 &/g;
}

elsif( $c =~ /^alt-text$/ ){
    my $afterdash = qr/(?<AFTERDASH>axis|plane)/;
    $q =~ s/'?(\w)'?-$afterdash/'$1'-$+{AFTERDASH}/g;
    $q =~ s/'?(\w)'?'?(\w)'?-$afterdash/'$1''$2'-$+{AFTERDASH}/g;
}

elsif( $c =~ /^lowercasenamesbroken$/ ){
    $q =~ s/("name"\s*:\s*"[^"]*?)([QWERTYUIOPASDFGHJKLZXCVBNM])/$1.lc($2)/eg;
}

elsif( $c =~ /^retag\s+(.*)\s*$/ ){
    my $tagname = $1;
    # end tags
    $q =~ s/${tagname}>/li>/g;
    # begin tags with difficulty
    $q =~ s/<${tagname}\s+difficulty=/<li order=/g;
    # begin tags
    $q =~ s/<${tagname}/<li/g;
}

elsif( $c =~ /^latexquote$/ ){
    $q = latexquote($q);
}

elsif( $c =~ /^attrsyntax$/ ){
    $q =~ s@\.(name|examples|counterexamples|importance|description|intuitions|notes|dependencies|plurals|negation|proofs)@.attrs['$1'].value@g;
}

elsif( $c =~ /^lowerstatus$/ ){
    sub sanitize{
        my ($w) = @_;
        # change space to -
        $w =~ s/ +/-/g;
        # make lowercase
        $w = lc($w);
        return $w
    }
    # big boy
    $q =~ s/(status.{0,20})\b(Open|In[- ]p?P?rogress|Cancell?ed|Certify|Abstained|Abstain|Revoked|Revoke|Uncertified|Certified|Closed|Complete|Signed[- ]o?O?ff|Expired|Pending|Rejected|Active|Reviewed|Review|Creating|Created|Updated|Inactive|Success|Failure|Remediated|Exception|Deleted|Expired|Disabled|No[- ]Certifier|Terminated|Unclaimed)\b/$1.sanitize($2)/gie;
}

elsif( $c =~ /^rmlog(?:ging)?$/ ){
    # Remove all logging statements.
    # For example, entire lines consisting of 'print(this)' or 'console.log(that)' will be removed.
    # note that you cannot use the | operator within lookahead/lookbehind, hence there are two separate lookbehinds
    $q =~ s@(?:(?<=^)|(?<=\n))\s*(?://)?\s*(?:console\.log|print|__\.pp)\s*\([^)]*\).*(?:$|\n)@@g;
}

elsif( $c =~ /^path$/ ){
    # Convert a *nix path to a Python import path for dbaas
    $q =~ s@/opt/workspace/dbaas/@@g;
    $q =~ s@\.py@@g;
    $q =~ s@/@.@g;
}
