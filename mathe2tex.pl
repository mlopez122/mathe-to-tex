#!/usr/bin/perl

use Text::Balanced qw (
    extract_delimited
    extract_bracketed
);

use strict;
use warnings;

#provides a warning if unconventional regex is used, avoids common regexp mistakes
use re 'strict'; 


#####################################
#Cmd line user prompt mode
#####################################

#print "Enter filename to translate: \n";
#my $filename = <STDIN>; #get filename from stdin to translate

#if filename doesn't exist, terminate
#open(DATA, $filename) or die "specified file name doesn't exist"; 

#####################################
#Argument-based file mode
#####################################

my $filename = $ARGV[0];
open(DATA, $filename) or die "provided file name doesn't exist";

#####################################

our $topLevelFraction = 0;
#read line by line until end of file
while (<DATA>) {
    
    my $currentLine = $_;

    #no boolean types in perl, but the 0 scalar evaluates to 'false'
    #this logic functions since the raw fractions are between pairs of QPh's and QPhI's
    #so although they're evaluated in different orders, this methodology still works
      

    $currentLine =~ s/\\/\\\\/g; #replace ALL '\' escape characters with '\\' to neutralize them

    if ($currentLine =~ /Sum/) { #Regexp for Summations
        $currentLine = processSum($currentLine);
    }
    if ($currentLine =~ /NIntegrate/) {
        $currentLine = processIntegrate($currentLine);
    }
    if ($currentLine =~ /W(\d\d+)/) { #Regexp for Whyp functions
        $currentLine = processWhyp($currentLine);
    }
    if ($currentLine =~ /QPh\[/) { #Regexp for QPh funs; need '[' to differ from QPhI funs
        $currentLine = processQPh($currentLine);
    }
    if ($currentLine =~ /QPhI/) { #Regexp for QPh funs; need '[' to differ from QPhI funs
        $currentLine = processQPhI($currentLine);
    }
    if ($currentLine =~ /QHypergeometricPFQ/) {
        $currentLine = processQhyp($currentLine);
    }
    if ($currentLine =~ /Binomial/) {
        $currentLine = processBinomial($currentLine);
    }
    
    #squash any remaining keywords denoted by \[...] in input (first step escaped these to \\[...])
    $currentLine =~ s/(\\\\\[[A-Z][a-z]+\])/grabTex($1)/ge;

    #squash any remaining top-level sqrt's
    $currentLine =~ s/Sqrt\[([(\w|\s)]+)\]/'\sqrt{' . grabTex($1) . '}'/ge;

    #print final output of the input line
    print $currentLine;
}

close(DATA); 

#string should be of format W<ab>[.....]
#where the <ab> is composed of 2 or more integers,
#W<ab> where a = b+1
#W<2 ints>[comma delimmitted elements; number of them equal to larger int]
#W functions cannot have a nested W inside
sub processWhyp
{
my $wString = $_[0]; # collect parameter string

do { #convert W's until finished
#match against regexp to collect indecies
$wString =~ /W(\d\d+)/; 

my $pre = substr($wString, 0, $-[0]); #pre contains all text before W, save for end concat step
my $wNum = substr($wString, $-[0], $+[0]-$-[0]); #contains W<ab> where a,b are ints
#contains ALL text starting with '['... ; where '...' is the contents of the Whyp function
my $post = substr($wString, $+[0]); 

#peel W off of numbers, so peel off first char in the string 
my $nums = substr($wNum, 1, length($wNum) - 1);

#process nums
my $numLength = length($nums);
#if odd number of digits, left one must take more digit; eg \Whyp{10}{9}
#if even, split evenly
my $lhs, my $rhs;
if ($numLength % 2 == 0)
{
    $lhs = substr($nums, 0, $numLength / 2);
    $rhs = substr($nums, $numLength / 2, $numLength);
} else {
    $lhs = substr($nums, 0, (int($numLength / 2) + 1));
    $rhs = substr($nums, (int($numLength / 2)+1), $numLength);
}
#now start concatenating for the beginning portion
#we can modify $wString directly since we saved the portions we needed
#pretext before 'W' + \Whyp + { lhs } + { rhs } is shown below
$wString = $pre . "\\Whyp" . '{' . $lhs . '}' . '{' . $rhs . '}';

#now come back to rest of input '$post'
#rest of input should be in form of [a,b,c,d...]...
#use extract_bracketed here to divvy the parts
my @pieces = extract_bracketed($post, '[]');

#@pieces is now an array of size 3 with following properties:
#$pieces[0] -> whole of bracketed contents of Whyp, includes outside pair of balanced square []'s
#$pieces[1] -> ALL remaining text that comes after the Whyp, must be saved for later
#$pieces[2] -> any preceding text before '['; however in this context should be the empty ""

#peel off surrounding []'s, replace with {}'s at the end
my $rawContents = substr($pieces[0], 1, length($pieces[0]) - 2);

#split on comma delimmiter; vars in array do not have commas
my @vars = split(',', $rawContents);

#call grabTex on all to convert to TeX, allowed since no custom macro
# inside a Whyp
#iterate through array to process them
my $i = 0;
#first element must be wrapped in its own set of '{}'
my $wBody = '{' . grabTex($vars[$i]) . '}' . '{';

$i++;
while ($i < @vars - 2)
{
    $wBody = $wBody . grabTex($vars[$i]);
    if ($i != @vars - 3) {
        $wBody = $wBody . ',';
    }
    $i++;
}

#add last two to final set of curly braces
$wBody = $wBody . '}' . '{' . grabTex($vars[$i]) . ',' . grabTex($vars[$i+1]) . '}';

#concat $wBody to outputTex, bring back post tex from before (represented earlier earlier $pieces[1])
$wString = $wString . $wBody . $pieces[1];

} while ($wString =~ /W(\d\d+)/); #Regexp for Whyp functions

#after all Whyp found:
return $wString;

}

#function for converting QPh functions
#given: QPh[{lst}, q, n] -> (lst; q)_{n} is translation
sub processQPh {
    my $qString = $_[0]; #collect parameter string
    
    do { #convert QPh's until finished
        #collect indecies
        $qString =~ /QPh\[/;
        my $pre = substr($qString, 0, $-[0]); #all text before Q, save for later on last step
        my $qType = substr($qString, $-[0], $+[0]-$-[0]-1); #has 'QPh', currently unused
        my $post = substr($qString, $+[0]-1); #has [{lst}, q, n] ...
        
        my @pieces = extract_bracketed($post, '[]');

        #@pieces is now an array of size 3 with following properties:
        #$pieces[0] -> whole of bracketed contents of QPh, includes outside pair of balanced square []'s
        #$pieces[1] -> ALL remaining text that comes after the QPh[...], must be saved for later
        #$pieces[2] -> any preceding text before '['; is "" in this context due to prior processing

        if (substr($pieces[1], 0, 1) eq '/') {
            $topLevelFraction = 1;
        }
        #peel off external []'s
        my $rawContents = substr($pieces[0], 1, length($pieces[0]) - 2);

        #extract again the '{lst}' contents
        my @internalPieces = extract_bracketed($rawContents, '{}');
        #$internalPieces[0] -> inside contents surrounded by {}
        #$internalPieces[1] -> remaining text, split on commas and manipulate
        #$internalPieces[2] -> empty again due to starting with '{'
        
        #peel off external {}'s and then call grabTex or grabTeXList on it
        my $internalRaw = substr($internalPieces[0], 1, length($internalPieces[0]) - 2);
        my $texList = "";
        if ($internalRaw =~ /,/g) { #if comma delimmited list
            $texList = grabTeXList($internalRaw);
        } else { #else just a single element
            $texList = grabTex($internalRaw);
        }

        my $qBody = "";

        if ($topLevelFraction == 1) { #prepend \frac{ heading
            $qBody = '\frac{';
        }
        #'( lst ;' is so far here
        $qBody = $qBody . '(' . $texList . ';';

        my @addOns = split(',', $internalPieces[1]);
        #$qBody now will become the correct in-place substitution
        #now is '( lst ; q)_{n}'
        $qBody = $qBody . grabTex($addOns[1]) . ')_{' . grabTex($addOns[2]) . '}'; 
        
        #fraction handling cases
        if ($topLevelFraction == 1) {
            $topLevelFraction = 2; # prepare for denominator
            $qBody = $qBody . '}{';
            $pieces[1] =~ s/\///;
        } else {
            if ($topLevelFraction == 2) {
                $topLevelFraction = 0; # reset indicator
                if (substr($pieces[1], 0, 1) eq ')') {
                    $pieces[1] =~ s/\)//;
                     $qBody = $qBody . ')}'; #close denominator in case of parentheses
                } else {
                     $qBody = $qBody . '}'; #close denominator
                }
            }
        }

        #now modify $qString by putting pieces back together
        $qString = $pre . $qBody . $pieces[1];
    } while ($qString =~ /QPh\[/); #Regexp for QPh

    #after all QPh found:
    return $qString;
}

sub processQPhI {
    my $qString = $_[0]; #collect parameter string
    
    do { #convert QPhI's until finished
        #collect indecies
        $qString =~ /QPhI/;
        my $pre = substr($qString, 0, $-[0]); #all text before Q, save for later on last step
        my $qType = substr($qString, $-[0], $+[0]-$-[0]); #has 'QPhI', currently unused
        my $post = substr($qString, $+[0]); #has [{lst}, q] ...
        
        my @pieces = extract_bracketed($post, '[]');

        #@pieces is now an array of size 3 with following properties:
        #$pieces[0] -> whole of bracketed contents of QPhI, includes outside pair of balanced square []'s
        #$pieces[1] -> ALL remaining text that comes after the QPhI[...], must be saved for later
        #$pieces[2] -> any preceding text before '['; is "" in this context due to prior processing

        if (substr($pieces[1], 0, 1) eq '/') {
            $topLevelFraction = 1;
        }

        #peel off external []'s
        my $rawContents = substr($pieces[0], 1, length($pieces[0]) - 2);

        #extract again the '{lst}' contents
        my @internalPieces = extract_bracketed($rawContents, '{}');
        #$internalPieces[0] -> inside contents surrounded by {}
        #$internalPieces[1] -> remaining text, split on commas and manipulate
        #$internalPieces[2] -> empty again due to starting with '{'
        
        #peel off external {}'s and then call grabTex or grabTeXList on it
        my $internalRaw = substr($internalPieces[0], 1, length($internalPieces[0]) - 2);
        my $texList = "";
        if ($internalRaw =~ /,/g) {
            $texList = grabTeXList($internalRaw);
        } else {
            $texList = grabTex($internalRaw);
        }

        my $qBody = "";

        if ($topLevelFraction == 1) { #prepend \frac{ heading
            $qBody = '\frac{';
        }

        $qBody = $qBody . '(' . $texList . ';';
        my @addOns = split(',', $internalPieces[1]);
        #$qBody now will become the correct in-place substitution
        $qBody = $qBody . grabTex($addOns[1]) . ')_{\infty}'; 
        
        #fraction handling cases
        if ($topLevelFraction == 1) {
            $topLevelFraction = 2; # prepare for denominator
            $qBody = $qBody . '}{';
            $pieces[1] =~ s/\///;
        } else {
            if ($topLevelFraction == 2) {
                $topLevelFraction = 0; # reset indicator
                if (substr($pieces[1], 0, 1) eq ')') {
                    $pieces[1] =~ s/\)//;
                     $qBody = $qBody . ')}'; #close denominator in case of parentheses
                } else {
                     $qBody = $qBody . '}'; #close denominator
                }
            }
        }

        #now modify $qString by putting pieces back together
        $qString = $pre . $qBody . $pieces[1];
    } while ($qString =~ /QPhI/); #Regexp for QPhI

    #after all QPh found:
    return $qString;
}

#given: Sum[f, {i, min, max}] -> '\sum_{i=min}^{max} f'
sub processSum {
    my $sumString = $_[0]; #param string
    do {   
        $sumString =~ /Sum/;
        my $pre = substr($sumString, 0, $-[0]); #all text before Sum, save for later on last step
        my $sType = substr($sumString, $-[0], $+[0]-$-[0]); #has 'Sum', currently unused
        my $post = substr($sumString, $+[0]); #has [f, {var, min,max}] ...

        #@sumPieces is now an array of size 3 with following properties:
        #$sumPieces[0] -> whole of bracketed contents of Sum, includes outside pair of balanced square []'s
        #$sumPieces[1] -> ALL remaining text that comes after the Sum[...], must be saved for later
        #$sumPieces[2] -> any preceding text before '['; is "" in this context due to prior processing
        my @sumPieces = extract_bracketed("$post", "[]");

        #Regexp places all text before bounds in matching group $1
        #then captures ', {bounds}' in group $2
        #removes all of group $2 from the string sumPieces
        #regex grouping to hop to last set of '{...}'
        #leading bracket and trailing bracket are matched off
        $sumPieces[0] =~ /^\[(.+), \{(.+)\}/g;
        my $fBody = $1; #this is f
        my $bounds = $2; #assign bounds

        #$boundsComponents[0] = i
        #$boundsComponents[1] = min
        #$boundsComponents[2] = max
        my @boundsComponents = split(',', $bounds); 
        my $sumBody = '\sum_{' . grabTex($boundsComponents[0]) . '=' . grabTex($boundsComponents[1]) . '}^{'. grabTex($boundsComponents[2]) . '}' . $fBody;

        #sumBody has correct summation form, BUT f is unevaluated, left for other functions
        $sumString = $pre . $sumBody . $sumPieces[1];
    } while ($sumString =~  /Sum/);
    return $sumString;
}

sub processBinomial {
    my $binomString = $_[0]; #param string
    do {
        $binomString =~ /(.+)Binomial\[ ?(\w+\^?\w*) ?, ?(\w+\^?\w*)\](.+\n)/;
        $binomString = $1 . "\\binom{$2}{$3}" . $4;
    } while ($binomString =~ /Binomial/);
    return $binomString
}
# QHypergeometricPFQ[{a_1,a_2,...a_n},{b_1,b_2,...},q,z] -> 
# \qhyp{length('a')}{length('b')}{a_1,a_2,...a_n}{b_1,b_2,...}{q,z}
sub processQhyp {
    my $qString = $_[0]; #param string
    do {
        $qString =~ /QHypergeometricPFQ/;
        my $pre = substr($qString, 0, $-[0]); #all text before QHyp, save for later on last step
        my $sType = substr($qString, $-[0], $+[0]-$-[0]); #has 'QHypergeometricPFQ', currently unused
        my $post = substr($qString, $+[0]); #has [{a_1,a_2,...a_n},{b_1,b_2,...},q,z] ...

        #@pieces is now an array of size 3 with following properties:
        #$pieces[0] -> whole of bracketed contents of Qhyp, includes outside pair of balanced square []'s
        #$pieces[1] -> ALL remaining text that comes after the Qhyp[...], must be saved for later
        #$pieces[2] -> any preceding text before '['; is "" in this context due to prior processing
        my @pieces = extract_bracketed($post, "[]");


        #peel off external []'s
        my $rawContents = substr($pieces[0], 1, length($pieces[0]) - 2);

        my @block = extract_bracketed($rawContents, '{}');
        #$block[0] = {a_1,a_2,...a_n}
        #$block[1] = ,{b_1,b_2,...},q,z
        #$block[2] = empty preceding due to context

        #peel external {}'s off of block[0]
        my $aBlock = substr($block[0], 1, length($block[0]) - 2);

        #obtain the second block and final variables, substring to peel off preceding comma
        my $remainder = substr($block[1], 1, length($block[1]) - 1);

        my @secondBlock = extract_bracketed($remainder, '{}');
        #$secondBlock[0] = {b_1,b_2,...}
        #$secondBlock[1] = ,q,z
        #$secondBlock[2] = empty due to context

        #obtain last two elements, peeled away preceding comma as well
        my $trailingVars = substr($secondBlock[1], 1, length($secondBlock[1]) - 1);

        #peel external {}'s again from 2nd block
        my $bBlock = substr($secondBlock[0], 1, length($secondBlock[0]) - 2);
        
        #a-block vars, array does not contain commas
        my @lhs = split(',', $aBlock);
        my $lengthOfA = @lhs; #returns length

        #b-block vars, array does not contain commas
        my @rhs = split(',', $bBlock);
        my $lengthOfB = @rhs; #returns length

        #begin crafting the body of Qhyp
        my $qBody = "\\qhyp{$lengthOfA}{$lengthOfB}{";

        #pass lhs to grabTexList
        if ($lengthOfA > 1) {
            $qBody = $qBody . grabTeXList($aBlock);
        } else {
            $qBody = $qBody . grabTex($lhs[0]);
        }
        #close off with a '}{' to process rhs
        $qBody = $qBody . "}{";
        
        #process rhs
        if ($lengthOfB > 1) {
            $qBody = $qBody . grabTeXList($bBlock);
        } else {
            $qBody = $qBody . grabTex($rhs[0]);
        }
        #close off with a '}'
        $qBody = $qBody . '}';

        #now add trailing vars
        $qBody = $qBody . "{$trailingVars}";
        
        #putting it all together
        #$pre is all pretext, $qbody is \qhyp, $pieces[1] is all post text after \qhyp
        $qString = $pre . $qBody . $pieces[1];

    } while ($qString =~ /QHypergeometricPFQ/);
    return $qString;
}

#replace Integrals (in this context the body of the integral
#will have already been converted)
#form: NIntegrate[f, {x, xmin, xmax}, WP -> n] -> \int_{min}^{max} f
sub processIntegrate {
    my $intString = $_[0]; #collect param string
    do {
        $intString =~ /NIntegrate/;
        my $pre = substr($intString, 0, $-[0]); #all text before NIntegrate, save for later on last step
        my $sType = substr($intString, $-[0], $+[0]-$-[0]); #has 'NIntegrate', currently unused
        my $post = substr($intString, $+[0]); #has [f, {var, min,max}] ...

        #@sumPieces is now an array of size 3 with following properties:
        #$sumPieces[0] -> whole of bracketed contents of NIntegrate, includes outside pair of balanced square []'s
        #$sumPieces[1] -> ALL remaining text that comes after the NIntegrate[...], must be saved for later
        #$sumPieces[2] -> any preceding text before '['; is "" in this context due to prior processing
        my @intPieces = extract_bracketed($post, "[]");

        #Regexp places all text before bounds in matching group $1
        #then captures ', {bounds}' in group $2
        #removes all of group $2 from the string sumPieces
        #regex grouping to hop to last set of '{...}'
        #leading bracket and trailing bracket are matched off
        $intPieces[0] =~ /^\[(.+), \{(.+)\}/g;
        my $fBody = $1; #this is f
        my $bounds = $2; #assign bounds

        #$boundsComponents[0] = i
        #$boundsComponents[1] = min
        #$boundsComponents[2] = max
        my @boundsComponents = split(',', $bounds); 
        my $intBody = '\int_{' . grabTex($boundsComponents[1]) . '}^{' . grabTex($boundsComponents[2]) . '}' . $fBody . '\, d' . grabTex($boundsComponents[0]);

        #sumBody has correct summation form, BUT f is unevaluated, left for other functions
        $intString = $pre . $intBody . $intPieces[1];
    } while ($intString =~ /NIntegrate/);
    return $intString;
}

#requires wolframscript to be installed
#parameter is a string that is in mathe form that need to be
#converted to TeX form
#works by calling the written command below on the shell; where
#$toConvert is the string passed in to convert
sub grabTex {
    #don't use $_ -> will pass caller's whole string to convert, use $_[0] for
    #parameter string
    my $toConvert = $_[0];
    #undo any \\ neutralizing done in main subroutine
    $toConvert =~ s/\\\\/\\/g; #replace ALL '\' escape characters with '\\' to neutralize them

    #if just '<char>_' remove the _ and just leave the letter:
    if ($toConvert =~ /[a-z]_$/) {
        $toConvert =~ s/_//;
    }
    
    #need the ' 's around $toConvert in order to protect the shell from metacharacters
    my $output = `wolframscript -code 'HoldForm[$toConvert]' -format TeXForm`;
    {
    #change chomp delimter to \n inside this code block only, don't want
    #extra newlines in our conversions
    local $/ = "\n";
    chomp($output);
    #print "$output\n";
    return $output;
    }
}

#takes comma delimmited items, wraps in a set of curly braces for a mathematica list
#and returns the whole list of TeXForms for each element (leading and trailing 
#\left and \right are removed)
#expects: a,b,c,d -- note, no wrapping '{}' expected!
sub grabTeXList {
    my $inputList = $_[0];
    $inputList =~ s/\\\\/\\/g; #replace ALL '\' escape characters with '\\' to neutralize them

    #if just '<char>_' remove the _ and just leave the letter:
    while ($inputList =~ /[a-z]_$/g) {
        $inputList =~ s/_//;
    }
    my $output = `wolframscript -code 'HoldForm[{$inputList}]' -format TeXForm`;
    {
    #change chomp delimter to \n inside this code block only, don't want
    #extra newlines in our conversions
    local $/ = "\n";
    chomp($output);
    #print "$output\n";
    }
    #remove leading and trailing \left and \right
    $output = substr($output, 7, -8);
    return $output;
}



# need a process "raw" function so it can find residual mathe (like '/') and convert it

#Qordering[q] = 1; SortBy[lst, QOrdering]  ... % is for most recent output
  #^this works tangentially, still reorders internal terms  
  #destructive: SetAttributes[Plus, Orderless = false]; SetAttributes[Times, Orderless = false];
  #this ^ approach does not work, as it says "protected" ... unsure where to go from here