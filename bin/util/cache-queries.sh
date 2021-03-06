#!/bin/bash
#
#3> <> prov:specializationOf <https://github.com/timrdf/csv2rdf4lod-automation/blob/master/bin/util/cache-queries.sh>;
#3>    rdfs:seeAlso          <https://github.com/timrdf/csv2rdf4lod-automation/wiki/Script:-cache-queries.sh>;
#3> .
#
#   Copyright 2012 Timothy Lebo
#
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.

outputTypes="sparql xml"

if [ $# -lt 1 ]; then
   echo "usage: `basename $0` <endpoint> [-p {output,format}] [-o {sparql,gvds,xml,exhibit,csv}+] [-q a.sparql b.sparql ...]* [--limit-offset] [-od path/to/output/dir]"
   echo
   echo "    Executes SPARQL queries against an endpoint requesting the given output formats."
   echo
   echo "            -p  : the URL parameter name used to request a different output/format from <endpoint>."
   echo "    default -p  : 'output'"
   echo "            -o  : the URL parameter value(s) to request."
   echo "    default -o  : $outputTypes"
   echo "    default -q  : *.sparql *.rq"
   echo " --limit-offset : iterate with LIMIT / OFFSET until no more useful results."
   echo "            -od : output directory"
   echo "    default -od : results/"
   exit 1
fi

# http://dbpedia.org/sparql
# format = 
# "text/html"                       HTML
# "application/vnd.ms-excel"        Spreadsheet
# "application/sparql-results+xml"  XML
# "application/sparql-results+json" JSON           &format=application%2Frdf%2Bxml
# "application/javascript"          Javascript
# "text/plain"                      NTriples
# "application/rdf+xml"             RDF/XML
# "text/csv"                        CSV

endpoint="http://logd.tw.rpi.edu/sparql"
endpoint="http://dbpedia.org/sparql"
endpoint="$1"
shift

outputVarName="output"
if [ "$1" == "-p" ]; then
   shift
   outputVarName="$1"
   shift
fi
#echo "`basename $0` using results format param: $outputVarName"

if [ "$1" == "-o" ]; then
   shift
   outputTypes=""
   while [ "$1" != "-q" -a $# -gt 0 ]; do
      outputTypes="$outputTypes $1"
      shift
   done
fi
#echo "`basename $0` using results format value: $outputTypes"

queryFiles=""
if [ $# -gt 0 -a "$1" == "-q" ]; then
   shift
   while [[ $# -gt 0 && ( "$1" != '-od' && "$1" != '--limit-offset' ) ]]; do
      queryFiles="$queryFiles $1"
      shift 
   done
else
   for sparql in `ls *.sparql *.rq 2> /dev/null`; do
      queryFiles="$queryFiles $sparql"
   done
fi

limit_offset=''
if [[ "$1" == '--limit-offset' ]]; then
   limit_offset='yes' 
   if [[ "$2" =~ [0-9]+ ]]; then
      #echo "`basename $0` accepting LIMIT override: $2" >&2
      limit_offset="$2" # An actual number.
      shift
   else
      echo "`basename $0` will use default LIMIT, or the LIMIT defined in the file ($2)." > /dev/null
      #echo "`basename $0` will use default LIMIT, or the LIMIT defined in the file ($2)." >&2
   fi
   shift
fi

results="results"
if [ "$1" == "-od" -a $# -gt 1 ]; then
   shift
   results="$1"
fi
if [ ! -d $results ]; then
   mkdir -p $results
fi

for sparql in $queryFiles; do
   echo $sparql
   for output in $outputTypes; do

      limit=''
      offset='0'
      if [[ -n "$limit_offset" ]]; then # limit_offset is either: '' (no), 'yes', or a caller-provided number e.g. '100000'
         limit=`cat $sparql | grep -i '^limit' | awk '{print $2}' | head -1`
         if [[ "$limit" =~ [0-9]+ ]]; then
            #echo "Found limit in $sparql: $limit" >&2
            limit_is_in_query='yes'
         else
            #echo "No LIMIT in $sparql; assuming default of 10000" >&2
            limit_is_in_query='no'
            limit='10000'
         fi
         if [[ "$limit_offset" =~ [0-9]+ ]]; then
            #echo "Overriding LIMIT to $limit_offset" >&2
            limit="$limit_offset"
         fi
         if [[ "$limit" =~ [0-9]+ ]]; then
            iteration='1'
         fi
      fi
      # limit  is either '' or a number e.g. '100000'
      # offset is always '0'
      echo "  (will exhaust with limit/offset: $limit/$offset)"

      while [ -n "$offset" ]; do
         queryOLD=`        cat  $sparql | perl -e 'use URI::Escape; @userinput = <STDIN>; foreach (@userinput) { print uri_escape($_); }'`
         query=`cr-urlencode.sh --from-file "$sparql"` # TODO: move to this.
         qi='' # '' -> '_2' -> '_3' ...
         queryOFFSET=''
         if [[ -n "$offset" ]]; then   
            if [[ "$offset" -gt 0 ]]; then
               qi=".$iteration"
               queryOFFSET=`cr-urlencode.sh " offset $offset "`
            fi
         fi
         escapedOutputOLD=`echo $output | perl -e 'use URI::Escape; @userinput = <STDIN>; foreach (@userinput) { chomp($_); print uri_escape($_); }'` # | sed 's/%0A$//'`
         escapedOutput=`cr-urlencode.sh $output`       # TODO: move to this.

         request="$endpoint?query=$query$queryOFFSET&$outputVarName=$escapedOutput"
         #echo $request

         resultsFile=$results/`basename $sparql`$qi.`echo $output | tr '/+-' '_'`
         if [[ "$offset" -eq 0 ]]; then
            printf "  $output -> $resultsFile"
         else
            echo   "  `echo $output | sed 's/./ /g'`    $iteration $limit/$offset"
         fi
         curl -L "$request" > $resultsFile 2> /dev/null

         #
         # Record the provenance of the query request
         #
         requestID=`resource-name.sh`
         requestDate=`dateInXSDDateTime.sh`
         $CSV2RDF4LOD_HOME/bin/util/cr-default-prefixes.sh --turtle                               > $resultsFile.prov.ttl
         echo "@prefix hartigprov: <http://purl.org/net/provenance/ns#> ."                       >> $resultsFile.prov.ttl
         echo "@prefix pmlp:       <http://inference-web.org/2.0/pml-provenance.owl#> ."         >> $resultsFile.prov.ttl
         echo "@prefix pmlj:       <http://inference-web.org/2.0/pml-justification.owl#> ."      >> $resultsFile.prov.ttl
         echo "@prefix pmlb:       <http://inference-web.org/2.b/pml-provenance.owl#> ."         >> $resultsFile.prov.ttl
         echo "@prefix oboro:      <http://obofoundry.org/ro/ro.owl#> ."                         >> $resultsFile.prov.ttl
         echo "@prefix oprov:      <http://openprovenance.org/ontology#> ."                      >> $resultsFile.prov.ttl
         echo                                                                                    >> $resultsFile.prov.ttl
         $CSV2RDF4LOD_HOME/bin/util/user-account.sh                                              >> $resultsFile.prov.ttl
         echo                                                                                    >> $resultsFile.prov.ttl
         pushd $results &> /dev/null
         $CSV2RDF4LOD_HOME/bin/util/nfo-filehash.sh "`basename $resultsFile`"                    >> `basename $resultsFile.prov.ttl`
         popd &> /dev/null
         echo                                                                                    >> $resultsFile.prov.ttl
         echo                                                                                    >> $resultsFile.prov.ttl
         echo "<`basename $resultsFile`>"                                                        >> $resultsFile.prov.ttl
         echo "   a prov:Entity;"                                                                >> $resultsFile.prov.ttl
         echo "   prov:wasQuotedFrom <$request>;"                                                >> $resultsFile.prov.ttl
         echo "."                                                                                >> $resultsFile.prov.ttl
         echo                                                                                    >> $resultsFile.prov.ttl
         echo "<$sparql.$output>"                                                                >> $resultsFile.prov.ttl
         echo "   a pmlp:Information;"                                                           >> $resultsFile.prov.ttl
         echo "   pmlp:hasModificationDateTime \"$requestDate\"^^xsd:dateTime;"                  >> $resultsFile.prov.ttl
         echo "   pmlp:hasReferenceSourceUsage <sourceusage$requestID>;"                         >> $resultsFile.prov.ttl
         echo "."                                                                                >> $resultsFile.prov.ttl
         echo                                                                                    >> $resultsFile.prov.ttl
         echo "<sourceusage_$requestID>"                                                         >> $resultsFile.prov.ttl
         echo "   a pmlp:SourceUsage;"                                                           >> $resultsFile.prov.ttl
         echo "   pmlp:hasSource        <$request>;"                                             >> $resultsFile.prov.ttl
         echo "   pmlp:hasUsageDateTime \"$requestDate\"^^xsd:dateTime;"                         >> $resultsFile.prov.ttl
         echo "."                                                                                >> $resultsFile.prov.ttl
         echo                                                                                    >> $resultsFile.prov.ttl
         echo "<$request>"                                                                       >> $resultsFile.prov.ttl
         echo "   a pmlj:Query, pmlp:Source;"                                                    >> $resultsFile.prov.ttl
         echo "   pmlj:isFromEngine <$endpoint>;"                                                >> $resultsFile.prov.ttl
         echo "   pmlj:hasAnswer    <nodeset$requestID>;"                                        >> $resultsFile.prov.ttl
         echo "."                                                                                >> $resultsFile.prov.ttl
         echo                                                                                    >> $resultsFile.prov.ttl
         echo "<$endpoint>"                                                                      >> $resultsFile.prov.ttl
         echo "   a pmlp:InferenceEngine, pmlp:WebService;"                                      >> $resultsFile.prov.ttl
         echo "."                                                                                >> $resultsFile.prov.ttl
         echo                                                                                    >> $resultsFile.prov.ttl
         echo "<nodeset_$requestID>"                                                             >> $resultsFile.prov.ttl
         echo "   a pmlj:NodeSet;"                                                               >> $resultsFile.prov.ttl
         echo "   pmlj:hasConclusion <$sparql.$output>;"                                         >> $resultsFile.prov.ttl
         echo "   pmlj:isConsequentOf <inferenceStep_$requestID>;"                               >> $resultsFile.prov.ttl
         echo "."                                                                                >> $resultsFile.prov.ttl
         echo "<inferenceStep_$requestID>"                                                       >> $resultsFile.prov.ttl
         echo "   a pmlj:InferenceStep;"                                                         >> $resultsFile.prov.ttl
         echo "   pmlj:hasIndex 0;"                                                              >> $resultsFile.prov.ttl
         echo "   pmlj:hasAntecedentList ("                                                      >> $resultsFile.prov.ttl
         echo "      [ a pmlj:NodeSet; pmlp:hasConclusion <query$requestID> ]"                   >> $resultsFile.prov.ttl
         echo "      [ a pmlj:NodeSet; pmlp:hasConclusion ["                                     >> $resultsFile.prov.ttl
         echo "            a pmlb:AttributeValuePair;"                                           >> $resultsFile.prov.ttl
         echo "            pmlb:attribute \"output\"; pmlb:value \"$output\""                    >> $resultsFile.prov.ttl
         echo "          ]"                                                                      >> $resultsFile.prov.ttl
         echo "      ]"                                                                          >> $resultsFile.prov.ttl
         echo "   );"                                                                            >> $resultsFile.prov.ttl
         echo "   oboro:has_agent          `$CSV2RDF4LOD_HOME/bin/util/user-account.sh --cite`;" >> $resultsFile.prov.ttl
         echo "   hartigprov:involvedActor `$CSV2RDF4LOD_HOME/bin/util/user-account.sh --cite`;" >> $resultsFile.prov.ttl
         #echo "      pmlj:hasSourceUsage     $sourceUsage;"                                     >> $resultsFile.prov.ttl
         #echo "      pmlj:hasInferenceEngine <$engine_name$requestID>;"                         >> $resultsFile.prov.ttl
         #echo "      pmlj:hasInferenceRule   conv:${engine_name}_Method;"                       >> $resultsFile.prov.ttl
         echo "."                                                                                >> $resultsFile.prov.ttl
         echo "<wasControlled_$requestID>"                                                       >> $resultsFile.prov.ttl
         echo "   a oprov:WasControlledBy;"                                                      >> $resultsFile.prov.ttl
         echo "   oprov:cause  `$CSV2RDF4LOD_HOME/bin/util/user-account.sh --cite`;"             >> $resultsFile.prov.ttl
         echo "   oprov:effect <inferenceStep$requestID>;"                                       >> $resultsFile.prov.ttl
         echo "   oprov:endTime \"$usageDateTime\"^^xsd:dateTime;"                               >> $resultsFile.prov.ttl
         echo "."                                                                                >> $resultsFile.prov.ttl
         echo ""                                                                                 >> $resultsFile.prov.ttl
         echo "<query_$requestID>"                                                               >> $resultsFile.prov.ttl
         echo "   a pmlb:AttributeValuePair;"                                                    >> $resultsFile.prov.ttl
         echo "   pmlb:attribute \"query\";"                                                     >> $resultsFile.prov.ttl
         echo "   pmlb:value     \"\"\"`cat $sparql`\"\"\";"                                     >> $resultsFile.prov.ttl
         echo "."                                                                                >> $resultsFile.prov.ttl

         # If query results are "valid", and we were asked to exhaust the query with limit/offset...
         if [[ `valid-rdf.sh $resultsFile` == 'yes' ]]; then
            if [[ -n "$offset" ]]; then   
               if [[ "$offset" -eq 0 ]]; then
                  echo
               fi
               let "offset=$offset+$limit"
               let "iteration=$iteration+1"
            fi
         else
            offset=''
         fi 
      done
   done
   echo ""
done 
