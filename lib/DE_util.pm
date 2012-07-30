package DE_util;
# A generalized wrapper for PHYLIP programs.
# individual wrapper scripts inherit from here

require Exporter;
use IO::File;
use Getopt::Std;
use List::Util 'sum';
use Digest::MD5 'md5_hex';
use File::Copy;
use Bio::SeqIO;
use Data::Dumper;

use constant SEQBOOT  => '/usr/local2/sheldon/bin/seqboot';
use constant CONSENSE => '/usr/local2/sheldon/bin/consense';
use constant TREEVECT => '/usr/local2/treevector-1.0/bin/treevector.jar';
use constant PREFS    => '/usr/local2/treevector-1.0/preferences/preferences.txt';

my $hashref = {};
my $ntax;

@ISA = 'Exporter';
@EXPORT = qw/random_number_key get_options run replicate make_treefile
             obfuscate_names deobfuscate_names cleanup consensus ntax/;

sub get_options {
    my $string  = shift or die "No options specified\n";
    $hashref = shift or die "Missing hash ref for options\n"; 
    ref $hashref or die "second argument must be a hash ref\n";
    getopts($string,$hashref);
    check_shared_options($hashref);
    cleanup();

    # files must always be interleaved, so set this option on
    $hashref->{I} = 1;

    return $hashref;
}

# shared options can be checked here
sub check_shared_options {
    my $opt = shift;
    my %opt = %$opt;

    unless ($opt{i}) {
	die "An input file name is required\n";
    }

    unless (-e $opt{i}) {
	die "File $opt{i} does not exist\n";
    }

    # make sure we are unix friendly
    system "dos2unix $opt{i}";

    if ($opt{J}) {
	die "J must be an integer (number of times to jumble)\n" unless $opt{J} && $opt{J} =~ /^\d+$/;
    }

    if ($opt{O}) {
	die "O must be an integer (species number)\n" unless $opt{O} && $opt{O} =~ /^\d+$/;
    }

    if ($opt{T}) {
        die "Tranition transversion ratio must be a positive integer or float"
            unless $opt{T} && $opt{T} =~ /^[.0-9]/;
    }

    if ($opt{F}){
        my @nums = grep /\S+/, split /\s+/, $opt{F};
        my $total = sum(@nums);
	
	unless (@nums == 4 && $total == 1) {
            die "Base frequencies for option F must be four float values that add up to 1\n";
        }
    }

    if ($opt{M}) {
	die "M must be an integer > 0 (number of replicates)\n" unless $opt{M} =~ /^\d+$/;
    }

}    

# make replicates if bootstrapping is asked for
sub replicate {
    my $num = shift or die "an integer (number of bootstrap replicates) is required";
    my $i   = shift;
    my $rand = random_number_key();
    my $stdin = "R\n$num\n";
    $stdin .= "I\n" unless $i;
    $stdin .= "Y\n$rand\n\n";
    run($stdin,SEQBOOT);
    unlink "infile";
    move("outfile", "infile");
}

# do consensus if bootstrapping is asked for
sub consensus {
    my $root = shift;
    move("outtree","mtrees.txt");
    cleanup();
    move("mtrees.txt","intree");
    my $stdin = '';
    #my $stdin = "C\nC\n"; # to get majority rule consensus
    $stdin .= "O\n$root\nR\n" if $root;
    $stdin .= "Y\n\n";
    run($stdin,CONSENSE);
    system 'perl -i -pe "s/[ \n]//g" outtree';
    system 'perl -i -pe "s/([a-h0-9]{32})\:[.0-9]+/\$1/g" outtree';
    system 'perl -i -pe "s/:|\.0//g" outtree';
}

# all purpose random key generator returns an odd integer
sub random_number_key {
    my $num = 0;
    until ($num > 1 && $num  % 2) {
	$num = rand;
	$num = int($num*10000);
    } 
    return $num
}

# return names to original form
sub deobfuscate_names {
    my $in  = shift or die "Provide an input file name";
    my $out = shift or die "Provide an output file name";
    my $name = shift or die "Provide a hashref of name keys";

    unless (-e $in && !-z $in) {
	die "File $in does not exist\nThe Run has failed.  Please consult the error logs\n"
    }

    my $fhi = IO::File->new($in);
    die "Could not open file handle for $in" unless $fhi;
    my $fho = IO::File->new("> $out");
    die "Could not open file handle for $out" unless $fho;

    while (my $l = <$fhi>) {
	chomp $l;
	if (my @keys = $l =~ /([0-9a-f]+)/g) {
	    for my $key (@keys) {
		next if length $key < 32;
		# sometimes numbered nodes act like part of key
                if (length $key > 32 && $key =~ /^\d+/) {
		    my $diff = (length $key) -  32;
		    $key =~ s/^\d{$diff}//;
		}

		my $real_name = $name->{$key} or warn "Could not find name for key $key!";
		$l =~ s/$key/$real_name/;
	    }
	    print $fho $l, "\n";
	}
	else {
	    print $fho $l, "\n";
	}
    }

    $fhi->close;
    $fho->close;
}


#fa2phy convert from fasta to phylip interleaved
sub fa2phy {
    my $file = shift;
    warn "Fasta detected: converting to phylip interleaved\n";
    my $in = Bio::SeqIO->new(-format => 'fasta', -file => $file);
    my $len;
    my @lines;
    
    while (my $seq = $in->next_seq) {
	$len ||= $seq->length;
	push @lines, join(' ',$seq->display_id,$seq->seq);
    }

    $ntax = @lines;
    ntax($ntax);
    my $out = IO::File->new(">fasta$$.phy");
    print $out join("\n", " $ntax $len",@lines), "\n";
    $out->close;
    my $names = obfuscate_names("fasta$$.phy", 'infile');
    unlink "fasta$$.phy";
    return $names;
}

# turn names into 32 char md5_hex digests
sub obfuscate_names {
    my $in  =  shift or die "Provide an input file name";
    my $out =  shift or die "Provide an output file name";

    #warn "I am running obfuscate on $in $out\n";

    unless (-e $in && !-z $in) {
        die "File $in does not exist\nThe Run has failed.  Please consult the error logs\n"
    }

    my %name = ();

    my $fhi = IO::File->new($in);
    die "could not open file handle for $in" unless $fhi;
    my $fho = IO::File->new("> $out");
    die "Could not open file handle for $out" unless $fho;

    my ($numtax,%seen);
    while (my $l = <$fhi>) {
        chomp $l;
	# Oops, they gave us fasta!
	if ($l =~ /^>/) {
	    return fa2phy($in);
	}

	if ($l =~ /^\s*(\d+)\s+\d+\s*$/) {
	    $numtax = $1;
	    ntax($numtax);
	    print STDERR "Number of taxa is $ntax\n";
	    print $fho " " if $l =~ /^\d/;
	    print $fho $l, "\n";
	}
	elsif ($l =~ /^(\S.*\s*)$/ && $numtax) {
	    my @x = split /\s+/, $l;
	    # Replace names with an md5_hex key but watch out for sequence
	    my $real_name = $x[0];
	    # get rid of bioperl's /1..300 name suffix
	    $real_name =~ s!/\d+\-\d+!!;
	    warn "Duplicate name! $real_name!\n" if $seen{$real_name}++;
	    my $name_key  = md5_hex($$.$real_name);
	    #warn "KEY $name_key VAL $real_name\n";
	    $name{$name_key} = $real_name;
	    $x[0] = $name_key;
	    print $fho "@x", "\n";
	    $numtax--;
	}
        else {
	    my $pad = " " x 33;
	    print $fho $pad if $l =~ /^\S/;
            print $fho $l, "\n";
        }
    }

    $fhi->close;
    print $fho "\n";
    $fho->close;

    return \%name;
}

sub ntax {
    $ntax = shift if @_;
    return $ntax;
}

# Do the actual work
sub run {
    my $stdin  = shift or die "No string passed to wrap";
    my $exe    = shift or die "No executable passed to wrap";
    my $log = IO::File->new(">>runlog.txt");
    print $log "The following parameters were passed to $exe:\n$stdin\n";

    system "echo '$stdin' | $exe";

    unless (-e 'outfile') {
	print $log "Job $exe failed, please check log files\n";
    }
    $log->close;

    return 1;
}

sub make_treefile {
    my $treefile = shift;
    die "Tree file $treefile is missing or empty!\n" 
	unless -e $treefile && !-z $treefile; 
    write_tv_html($treefile);
    write_tv_treefile($treefile);
}

# get rid of cruft
sub cleanup {
    for (qw/infile intree outfile outtree/) {
	unlink $_;
    }
}

sub write_tv_treefile {
    my $newick   = shift;
    my $num_taxa = ntax();
    my $cmd = TREEVECT . " $newick ";
    $cmd .= '-square ';
    $cmd .= '-out treefile.svg ';
    $cmd .= `grep '\:' $newick` ? '-phylo ' : '-clad ';
    my ($x,$y) = (800,300);
    #warn "There are $num_taxa taxa in this tree\n";
    $y += $num_taxa * 18;
    $cmd .= "-size $x $y";
    $cmd .= " -prefs ".PREFS;

    system("$cmd 2> /dev/null");

    # use ImageMagick's convert to make png version
    system("convert svg:treefile.svg png:treefile.png") if -e 'treefile.svg';
    unlink "output.tre" if -e "output.tre";
    unlink "output.xml" if -e "output.xml";
}

#Create file
sub write_tv_html {
    my $file = shift;
    my $tree = `cat $file`;
    $tree =~ s/\n//gm;

  my $HTMLOUT = IO::File->new('>TreeVector.html');
  print $HTMLOUT <<END;
  <html>
     <body>
     <h2>TreeVector (supfam.cs.bris.ac.uk/TreeVector)</h2>
     <form name=tvec method=post action="http://supfam.cs.bris.ac.uk/TreeVector/cgi-bin/maketree.cgi">
      <div style="display:none">
       <textarea name=topology>
       $tree
       </textarea>
      </div>
      Width: <input type="text" size="25" name="x" value="1280" /> Height: <input type="text" size="25" name="y" value="1024"><br />
      </p>
      <p>
      Choose a tree type:
      &nbsp;<input type="radio" name="treetype" value="-clad"> Cladogram 
      &nbsp;<input type="radio" name="treetype" value="-simpleclad" checked> Simple Cladogram 
      &nbsp;<input type="radio" name="treetype" value="-phylo"> Phylogram
     </p>
     <p>
      Choose a tree shape:
      &nbsp;<input type="radio" name="treeshape" value="-square" checked> Square 
      &nbsp;<input type="radio" name="treeshape" value="-triangle"> Triangular 
     </p>
     <p>
     Select output format:
      &nbsp;<input type="radio" name="output" value="png" checked> PNG
      &nbsp;<input type="radio" name="output" value="pdf"> PDF 
      &nbsp;<input type="radio" name="output" value="svg"> SVG
     </p>
      <input class="submit" type="submit" value="View" value="Submit"/> 
    </form>
   </body>
  </html>
END
;


  $HTMLOUT->close;

}

1;
