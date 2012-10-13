#!/bin/bash
#
# install.sh - determine CSV2RDF4LOD_HOME and create configuration file.
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

ext="sh"
if [ "$1" == "--csh" ]; then
   ext="csh"
fi

CSV2RDF4LOD_HOME=`pwd`
echo "#3 <#> a <http://purl.org/twc/vocab/conversion/CSV2RDF4LOD_environment_variables> ;"    > my-csv2rdf4lod-source-me.${ext}
echo "#3     rdfs:seeAlso"                                                                   >> my-csv2rdf4lod-source-me.${ext}
echo "#3     <https://github.com/timrdf/csv2rdf4lod-automation/wiki/CSV2RDF4LOD-environment-variables-%28considerations-for-a-distributed-workflow%29>," >> my-csv2rdf4lod-source-me.${ext}
echo "#3     <https://github.com/timrdf/csv2rdf4lod-automation/wiki/Script:-source-me.sh>" . >> my-csv2rdf4lod-source-me.${ext}
echo ""                                                                                     >> my-csv2rdf4lod-source-me.${ext}
echo "export CSV2RDF4LOD_HOME=\"$CSV2RDF4LOD_HOME\""                                        >> my-csv2rdf4lod-source-me.${ext}
echo "`basename $0`:"
echo "   has created my-csv2rdf4lod-source-me.${ext}."
echo "   has set \$CSV2RDF4LOD_HOME to $CSV2RDF4LOD_HOME in my-csv2rdf4lod-source-me.${ext}"

cat bin/setup.sh | grep -v "# _NOTE_" | grep -v "# _WARNING_" >> my-csv2rdf4lod-source-me.sh

if [ "$1" == "--csh" ]; then
 # perl -pi -e
   perl -pe 's/export [^ =]*$//; s/^(\w+)="([^"]*)"/setenv \1 "\2"/; s/export (\S+)="([^"]*)"/setenv \1 "\2"/' \
         my-csv2rdf4lod-source-me.sh > my-csv2rdf4lod-source-me.csh
elif [ "$1" == "--cygwin" ]; then
   echo "--cygwin not implemented"
fi

echo ""

echo
echo "~~~ What to do next: ~~~"
echo
echo "   'source my-csv2rdf4lod-source-me.${ext}' to set the environment variables needed to run csv2rdf4lod-automation."
echo "    sourcing my-csv2rdf4lod-source-me.${ext} must be done each time you log in, so consider adding this to your .bashrc:"
echo ""
echo "      source $CSV2RDF4LOD_HOME/my-csv2rdf4lod-source-me.${ext} # http://purl.org/twc/id/software/csv2rdf4lod"
echo ""
echo "    run cr-vars.${ext} to see the environment variables that CSV2RDF4LOD uses to control execution flow."
echo "    see https://github.com/timrdf/csv2rdf4lod-automation/wiki/Installing-csv2rdf4lod-automation"
echo
echo "    run 'cr-vars.${ext} --check' to check for dependencies."
echo "    run install-csv2rdf4lod-dependencies.sh to install dependencies."
mv install.sh bin/
source created my-csv2rdf4lod-source-me.${ext} &> /dev/null


echo "Put the following 'source' command into your ~/.bashrc?"
echo "      source $CSV2RDF4LOD_HOME/my-csv2rdf4lod-source-me.${ext} # http://purl.org/twc/id/software/csv2rdf4lod"
echo -n "(y/N) "
read -u 1 install_it
if [ "$install_it" == "y" ]; then
   echo                                                                                                                >> ~/.bashrc
   echo "      source $CSV2RDF4LOD_HOME/my-csv2rdf4lod-source-me.${ext} # http://purl.org/twc/id/software/csv2rdf4lod" >> ~/.bashrc
fi

echo -n "Try to install dependencies? (y/N) "
read -u 1 install_it
if [ "$install_it" == "y" ]; then
   install-csv2rdf4lod-dependencies.sh
fi

echo -n "'source' my-csv2rdf4lod-source-me.${ext} now? (Y/n) "
read -u 1 install_it
if [ "$install_it" != "n" ]; then
   source $CSV2RDF4LOD_HOME/my-csv2rdf4lod-source-me.${ext}
fi
