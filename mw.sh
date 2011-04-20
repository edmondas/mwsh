#!/bin/sh

# Copyright (c) 2011, Edmondas Girkantas <eg@fbsd.lt>
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# * Redistributions of source code must retain the above copyright notice,
#   this list of conditions and the following disclaimer.
# * Redistributions in binary form must reproduce the above copyright
#   notice, this list of conditions and the following disclaimer in the
#   documentation and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND ANY
# EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE FOR ANY
# DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
# (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
# CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
# LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
# OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH
# DAMAGE.

PROFILE=~/.mwshrc
TEMPLATE_DIR=templates

checkCountOfArguments()
{
	if [ "$1" -lt 1 ]
	then
		showUsage
		exit
	fi
}

assertEqual()
{
	if [ "$1" != "$2" ]
	then
		echo "\n! Test failed: $1 != $2"
		exit
	else
		echo " OK"
	fi
}

checkIfCommandAvailable()
{
	local result=`$1 2>/dev/null`
	local code=$?

	if [ "$code" = "127" ]
	then
		echo "Error: can't find command <$1> on system"
		exit
	fi
}

checkCommand()
{
	local command=$1
	if [ "$command" != "info" ] &&
		[ "$command" != "blogs" ] &&
		[ "$command" != "cats" ] &&
		[ "$command" != "posts" ] &&
		[ "$command" != "remove" ] &&
		[ "$command" != "delete" ] &&
		[ "$command" != "rm" ] &&
		[ "$command" != "ls" ] &&
		[ "$command" != "list" ] &&
		[ "$command" != "new" ] &&
		[ "$command" != "edit" ] &&
		[ "$command" != "test" ] &&
		[ "$command" != "get" ]
	then
		echo "Error: unknown command <"$command">"
		exit
	fi
}

showUsage()
{
	cat << EOF
Usage: $0 <command> [<post_id>]

Available commands:
  blogs  - returns a list of blogs to which user has posting privileges.
  cats   - returns the list of categories that have been used in the blog.
  edit   - edits an existing entry on a blog.
  get    - returns a specific entry from a blog.
  info   - returns basic user information. 
  new    - posts a new entry to a blog.
  posts  - returns the most recent draft and non-draft blog posts.
  remove - deletes a post from the blog.

Aliases:
  posts  - ls, list
  remove - rm, delete

EOF
}

doesProfileExists()
{
	local ret=0

	if [ -f ~/.mwshrc ]
	then
		local ret=1
	fi
	
	echo $ret
}

createProfile()
{
	echo "Creating new profile..."

	echo "Please provide your blog url:"
	read url

	echo "Please give your username:"
	read user 

	touch $PROFILE
	chmod 0600 $PROFILE

	echo "url=$url" >> $PROFILE 
	echo "user=$user" >> $PROFILE 

	echo "Blog settings saved to $PROFILE"
}

getConfValue()
{
	local val=`cat $1 | grep $2= | sed 's/'$2'=//'`
	echo $val
}

readPassword()
{
	local oldmode=`stty -g`

	stty -echo
	read password
	stty $oldmode

	echo $password
}

getEndpointUrl()
{
	local url=$1

	local host=`echo $url | cut -d '/' -f3`
	local suburl=`echo $url | cut -d '/' -f4`
	local blogname=`echo $url | cut -d '/' -f5`

	local blogurl="http://$host/$suburl/$blogname/_layouts/metaweblog.aspx"
	
	echo $blogurl
}

testGetEndpointUrl()
{
	url="http://my.domain.com/Blogs/Blog_name/Pages/default.aspx"
	printf "%s" "- testFindProjects()"
        endpurl=$(getEndpointUrl $url)
        assertEqual "$endpurl" "http://my.domain.com/Blogs/Blog_name/_layouts/metaweblog.aspx"
}

sendXml()
{
	xml=`cat $TEMPLATE_DIR/$1 | curl -s --ntlm -u $3:$4 -X POST -H 'Content-type: text/xml' -d @- $2`
	echo $xml
}

sendXmlAndPostId()
{
	xml=`cat $TEMPLATE_DIR/$1 | sed 's/POSTID/'$5'/' | curl -s --ntlm -u $3:$4 -X POST -H 'Content-type: text/xml' -d @- $2`
	echo $xml
}

sendXmlWithArgs()
{
	date=`date +%Y%m%dT%H:%M:%S`
	xml=`cat $TEMPLATE_DIR/$1 | sed -e 's/TITLE/'"$5"'/' -e 's/CATEGORY/'"$6"'/' -e 's/DESCRIPTION/'"$7"'/' -e 's/DATE/'$date'/' -e 's/STATUS/'$8'/' | curl -s --ntlm -u $3:$4 -X POST -H 'Content-type: text/xml' -d @- $2`
	echo $xml
}

sendXmlWithArgs2()
{
	date=`date +%Y%m%dT%H:%M:%S`
	xml=`cat $TEMPLATE_DIR/$1 | sed -e 's/TITLE/'"$5"'/' -e 's/POSTID/'$6'/' -e 's/DESCRIPTION/'"$7"'/' -e 's/DATE/'$date'/' -e 's/STATUS/'$8'/' | curl -s --ntlm -u $3:$4 -X POST -H 'Content-type: text/xml' -d @- $2`
	echo $xml
}

checkPassword()
{
	local ret=0 
	local output=`curl -sL -w "%{http_code}\\n" --ntlm -u $2:$3 -o /dev/null $1`;

	if [ "$output" = "200" ]
	then
		ret=1
	fi

	echo $ret	
}

# MAIN
if [ $(doesProfileExists) -eq 0 ]
then
	createProfile
	exit
fi

checkCountOfArguments $#

command=$1

checkCommand $command

if [ "$command" = "test" ]
then
	echo "Running tests:"
	testGetEndpointUrl

	exit
fi

checkIfCommandAvailable "curl"

url=$(getConfValue $PROFILE "url")
user=$(getConfValue $PROFILE "user")

endurl=$(getEndpointUrl $url)

password=$(getConfValue $PROFILE "password")
if [ "$password" = "" ]
then
	echo "Enter your blog password:"
	password=$(readPassword)
fi

if [ $(checkPassword $url $user $password) -eq 0 ]
then
	echo "Bad password!"
	exit
else
	echo "Password is OK"
fi

case "$command" in
	"info")
		echo "Blog info:"
		xml=$(sendXml "getUserInfo.xml" $endurl $user $password)
		echo "$xml" | awk -f xmlparse.awk
	;;

	"blogs")
		echo "Blogs:"
		xml=$(sendXml "getUsersBlogs.xml" $endurl $user $password)
		echo "$xml" | awk -f xmlparse.awk
	;;

	"get")
		postid=$2
		if [ "$postid" = "" ]
		then
			echo "Enter post id:"
			read postid
		fi

		echo "Post:"
		xml=$(sendXmlAndPostId "getPost.xml" $endurl $user $password $postid)
		echo "$xml" | awk -f xmlparse.awk
	;;

	"cats")
		echo "Categories:"
		xml=$(sendXml "getCategories.xml" $endurl $user $password)
		echo "$xml" | awk -f xmlparse.awk
	;;

	"posts"|"ls"|"list")
		echo "Recent posts:"
		xml=$(sendXml "getRecentPosts.xml" $endurl $user $password)
		echo "$xml" | awk -f xmlparse.awk
	;;

	"remove"|"delete"|"rm")
		postid=$2
		if [ "$postid" = "" ]
		then
			echo "Enter post id:"
			read postid
		fi

		echo "Do you really want to remove post with id $postid? Answer y/n:"
		read answer
		if [ "$answer" != "y" ]
		then
			echo "Post removal was canceled"
			exit
		fi

		echo "Response:"
		xml=$(sendXmlAndPostId "deletePost.xml" $endurl $user $password $postid)
		echo "$xml" | awk -f xmlparse.awk
	;;

	"new")
		echo "Enter title:"
		read title 

		echo "Enter category:"
		read category

		echo "Enter description:"
		read description
		
		echo "Status (published - 1, draft - 0):"
		read status

		echo "Response:"
		xml=$(sendXmlWithArgs "newPost.xml" $endurl $user $password "$title" "$category" "$description" $status)
		echo "$xml" | awk -f xmlparse.awk
	;;

	"edit")
		echo "Warning: Current editing implementation is incomplete.\nIt will replace all content in selected post."
		echo "Press CTRL+C if you want stop editing\n"

		postid=$2
		if [ "$postid" = "" ]
		then
			echo "Enter post id:"
			read postid
		fi

		echo "Enter title:"
		read title

		echo "Enter description:"
		read description

		echo "Status (published - 1, draft - 0):"
		read status

		echo "Response:"
		xml=$(sendXmlWithArgs2 "editPost.xml" $endurl $user $password "$title" $postid "$description" $status)
		echo "$xml" | awk -f xmlparse.awk
	;;

esac

