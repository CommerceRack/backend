package REPORT::IMAGE_ASSOC;

use strict;
use lib "/backend/lib";
use ZOOVY;
# use POGS;

require DBINFO;
use Data::Dumper;


##
## REPORT: IMAGE_ASSOC
##

sub new { my ($class) = @_; my $self = {}; bless $self, $class; return($self); }
sub r { return($_[0]->{'*PARENT'}); }

sub init {
	my ($self) = @_;

	my ($r) = $self->r();
	my $meta = $r->meta();

	$meta->{'title'} = 'Image Associations Report';

	$r->{'@HEAD'} = [
		{ id=>0, 'name'=>'Image', type=>'CHR', },
		{ id=>1, 'name'=>'Image Path', type=>'CHR',  },
		{ id=>2, 'name'=>'Image Type', type=>'CHR', },	
		{ id=>3, 'name'=>'PID', type=>'CHR', link=>'/biz/product/index.cgi?VERB=QUICKSEARCH&VALUE=', target=>'_blank' },
		{ id=>4, 'name'=>'Product Name', type=>'CHR', },
		];

#	$self->{'@DASHBOARD'} = [
#			{ 
#			'name'=>'By Product Type', 
#			'@HEAD'=>[ 
#				{ type=>'CHR', name=>'Product Type', src=>1 },
#				{ type=>'CNT', name=>'Count', src=>1 },
#				],
#			'groupby'=>1, 			
#			},
#			{ 
#			'name'=>'By Error', 
#			'@HEAD'=>[ 
#				{ type=>'CHR', name=>'Error', src=>3 },
#				{ type=>'CNT', name=>'Count', src=>3 },
#				],
#			'groupby'=>3, 			
#			},
#
#		];


	$r->{'@BODY'} = [];

	return(0);
	}



###################################################################################
##
sub work {
	my ($self) = @_;

	my ($r) = $self->r();
	my $USERNAME = $r->username();

	my $dbh =&DBINFO::db_user_connect($USERNAME);

	my @info = ();
	my %prods = &ZOOVY::fetchproducts_by_name($USERNAME);

	my @PIDS = keys %prods;

	my $jobs = &ZTOOLKIT::batchify(\@PIDS,250);

	my $reccount = 0;
	my $rectotal = scalar(@{$jobs});

	foreach my $pidsref (@{$jobs}) {
		# my $prodrefs = ZOOVY::fetchproducts_into_hashref($USERNAME,$pidsref);
		my $Prodrefs = &PRODUCT::group_into_hashref($USERNAME,$pidsref);
		foreach my $P (values %{$Prodrefs}) {
			my $PID = $P->pid();
			my $prod_name = $P->fetch('zoovy:prod_name');

			## check zoovy:prod_image 1-10
			for (my $i=1;$i<11;$i++) {
				my $type = 'zoovy:prod_image'.$i;
				my $image = $P->fetch($type);
				next if ($image eq '');			
	
				push @info, $PID."|".$image."|".$type."|".$P->fetch('zoovy:prod_name');
				}
			## check zoovy:prod_thumb
			if ($P->fetch('zoovy:prod_thumb') ne '') {
				push @info, $PID."|".$P->fetch('zoovy:prod_thumb')."|zoovy:prod_thumb|".$P->fetch('zoovy:prod_name');
				}
		
			## should add check for POG/SOG images
			foreach my $pog (@{$P->fetch_pogs()}) {
				next unless ($pog->{'type'} eq 'imgselect' || $pog->{'type'} eq 'imggrid');	
				foreach my $opt (@{$pog->{'@options'}}) {
					if ($opt->{'img'}) {
						push @info, $PID."|".$opt->{'img'}."|imgselect ".$pog->{'id'}.":".$opt->{'v'}."|".$P->fetch('zoovy:prod_name');
						}
					}
				#foreach my $o (@{$pog->{'options'}}) {
				#	my $metaref = POGS::parse_meta($o->{'m'});
				#	if ($metaref->{'img'} ne '') {
				#		my $imgselect = $metaref->{'img'};
				#		push @info, $PID."|".$imgselect."|imgselect ".$pog->{'id'}.":".$o->{'v'}."|".$P->fetch('zoovy:prod_name');
				#		}
				#	}
				}

			}
		$r->progress(++$reccount,$rectotal,"Loading product batches from database");
		}
   &DBINFO::db_user_close();


	my $batchref = &ZTOOLKIT::batchify(\@info,250);

	my $batch = pop @{$self->{'@JOBS'}};

	$reccount = 0;
	$rectotal = scalar(@{$batchref});
	foreach my $batch (@{$batchref}) {
		foreach my $info (@{$batch}) {
			my $error = '';
			my ($prod,$path,$type,$prod_name) = split(/\|/,$info);
	
			my $img_url = &ZOOVY::mediahost_imageurl($USERNAME,$path,50,50,'FFFFFF',0);
			my $big_img_url = &ZOOVY::mediahost_imageurl($USERNAME,$path,'','','FFFFFF',0);
			my $image = qq~<a href=javascript:openWindow("$big_img_url")><img src="$img_url" height='50' width='50' border='0'></a>~;

			my @ROW = (
				$image,
				$path,
				$type,
				$prod,
				$prod_name,
				);
	
			push @{$r->{'@BODY'}}, \@ROW;
			}
		$r->progress(++$reccount,$rectotal,"Creating report");
		}			

	$self->{'jobend'} = time()+1;
	}



1;

