#!/bin/bash
RBOT_PLUGINS_DIR=$1
if [ -d $RBOT_PLUGINS_DIR ]
then
    if [ -w $RBOT_PLUGINS_DIR ]
    then
        for plugin in `ls *rb`
        do
            destination=$RBOT_PLUGINS_DIR/$plugin
            if [ -a $destination ]
            then
                echo "A plugin named $plugin already exists. Skipping."
            else
                ln -s $PWD/$plugin $destination
                echo "Added $plugin."
            fi
        done
    else
        echo "$RBOT_PLUGINS_DIR is not writable."
    fi
else
    echo "$RBOT_PLUGINS_DIR does not exist."
fi
