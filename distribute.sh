#!/bin/sh

parent_dir="cf100"
sub_dirs=( cf90internal cf90test )
ports=( 7009 7008 )

for i in "${!sub_dirs[@]}"
do
  mkdir -p ../$parent_dir/${sub_dirs[$i]}
  cp -r * ../$parent_dir/${sub_dirs[$i]}
  cd ../$parent_dir/${sub_dirs[$i]}
  port=${ports[$i]}
  sed -i '3s/.*/PORT = '$port'/' cf70.rb
  ruby cf70.rb &> access.log &
  cd ../../badger
done
