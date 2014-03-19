update SITE_EMAILS set METAJSON=replace(METAJSON,"\n",",");

commit;
