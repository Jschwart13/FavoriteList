#!/bin/bash
insert_to_db(){
  docker run --network=host --rm mysql mysql -N -h127.0.0.1 -uroot -pmy-secret-pw -DTestDB -e'INSERT into TestDB.'$whatAreYouWatching'(title, description, ranking) VALUES ("'$t'", "'$d'", "'$r'");' 2>/dev/null | grep -v "mysql: [Warning] Using a password on the command line interface can be insecure."
}

add_1_to_all_existing_ranks(){
  docker run --network=host --rm mysql mysql -N -h127.0.0.1 -uroot -pmy-secret-pw -DTestDB -e'Update TestDB.'$whatAreYouWatching' set ranking = ranking + 1 where ranking >= '$r';' 2>/dev/null | grep -v "mysql: [Warning] Using a password on the command line interface can be insecure."
}

select_count_from_db(){
  docker run --network=host --rm mysql mysql -N -h127.0.0.1 -uroot -pmy-secret-pw -DTestDB -e'SELECT COUNT(*) from TestDB.'$whatAreYouWatching';' 2>/dev/null | grep -v "mysql: [Warning] Using a password on the command line interface can be insecure."
}

select_where_ranking_equals_r(){
  docker run --network=host --rm mysql mysql -N -h127.0.0.1 -uroot -pmy-secret-pw -DTestDB -e'SELECT title from TestDB.'$whatAreYouWatching' where ranking = '$r';' 2>/dev/null | grep -v "mysql: [Warning] Using a password on the command line interface can be insecure."
}

worstRank(){
  docker run --network=host --rm mysql mysql -N -h127.0.0.1 -uroot -pmy-secret-pw -DTestDB -e'SELECT ranking from TestDB.'$whatAreYouWatching' order by ranking DESC LIMIT 0,1;' 2>/dev/null | grep -v "mysql: [Warning] Using a password on the command line interface can be insecure."
}

setWorseRankPlusOne(){
  worstRankVar=$(worstRank)
  worstRankPlusOne=$( expr $worstRankVar + 1)
}

completionMessage(){
  echo "Done!"
}

displayCurrentResults(){
  echo "Here are your current results!"
  docker run --network=host --rm mysql mysql -h127.0.0.1 -uroot -pmy-secret-pw -DTestDB -e'SELECT ranking, title from TestDB.'$whatAreYouWatching' order by ranking ASC;' 2>/dev/null | grep -v "mysql: [Warning] Using a password on the command line interface can be insecure."
}

insertCompletionMessageAndDisplay(){
  insert_to_db
  completionMessage
  displayCurrentResults
}

docker run --network=host --rm mysql mysql -h127.0.0.1 -uroot -pmy-secret-pw -e'CREATE DATABASE IF NOT EXISTS TestDB;' 2>/dev/null | grep -v "mysql: [Warning] Using a password on the command line interface can be insecure."
echo "Bringing up your DB :)
"

sleep 1s

echo "Here is a list of all of your movie franchises!
"
docker run --network=host --rm mysql mysql -h127.0.0.1 -uroot -pmy-secret-pw -DTestDB -e'show tables;' 2>/dev/null | grep -v "mysql: [Warning] Using a password on the command line interface can be insecure."

echo ""

shopt -s nocasematch
echo -n "What did you watch today? (1 word, for example StarWars): "
read whatAreYouWatching

echo -n "I'm glad you are watching" $whatAreYouWatching ". Can you type title of the" $whatAreYouWatching "episode?: "
read t

echo -n "Can you give a brief description of" $t "?: "
read d

doesYourTableExist=$(docker run --network=host --rm mysql mysql -N -h127.0.0.1 -uroot -pmy-secret-pw -DTestDB -e'show tables like "'$whatAreYouWatching'"' 2>/dev/null | grep -v "mysql: [Warning] Using a password on the command line interface can be insecure.")

if [[ $doesYourTableExist != '' ]]; then
  count=$(select_count_from_db)
  echo -n "If you were to rank it, where do you think it would rank against all other episodes of" $whatAreYouWatching "? (Just remember you have" $count "entries right now): "
  read r
else
  echo -n "If you were to rank it, where do you think it would rank against all other episodes of" $whatAreYouWatching "?: "
  read r
fi

echo "Do I have this right? The title is:" $t
echo "The description is:" $d
echo "And the initial ranking is:" $r

docker run --network=host --rm mysql mysql -N -h127.0.0.1 -uroot -pmy-secret-pw -DTestDB -e'CREATE TABLE if not EXISTS TestDB.'$whatAreYouWatching'( title varchar(255), description varchar(255), ranking int );' 2>/dev/null | grep -v "mysql: [Warning] Using a password on the command line interface can be insecure."
count=$(select_count_from_db)

if [[ $count == 0 ]]; then
  echo "Oh cool this is the first entry for '$whatAreYouWatching'! Let's default your ranking to 1."
  declare -i r=1
  insertCompletionMessageAndDisplay
  exit 1;
elif [[ $count == 1 ]]; then
  echo "This is only the second entry for '$whatAreYouWatching'!"
  onlyTitle=$(docker run --network=host --rm mysql mysql -N -h127.0.0.1 -uroot -pmy-secret-pw -DTestDB -e'SELECT title from TestDB.'$whatAreYouWatching';' 2>/dev/null | grep -v "mysql: [Warning] Using a password on the command line interface can be insecure.")
  echo -n "Is" $t "better than" $onlyTitle "? (yes or no) "
  read answer
  if [[ $answer == 'yes' ]]; then
    declare -i r=1
    echo "Nice. Setting this as #1."
    add_1_to_all_existing_ranks
    insertCompletionMessageAndDisplay
    exit 1;
  elif [[ $answer == "no" ]]; then
    declare -i r=2
    echo "Nice. Setting this as #2."
    insertCompletionMessageAndDisplay
    exit 1;
  else echo "please enter yes or no, you silly person."
  fi
else
  currentRankingTitle=$(select_where_ranking_equals_r)
fi

while [[ r -gt 0 && $currentRankingTitle != '' ]]; do
  worstRankVar=$(worstRank)
  echo -n "Is" $t "better than" $currentRankingTitle "? (yes or no) "
  read answer
  if [[ $answer == "yes" ]]; then
    rankingTitleBeforeNo=$currentRankingTitle
    declare -i r=$( expr $r - 1 )
    currentRankingTitle=$(select_where_ranking_equals_r)
    if [[ $r == 0 ]]; then
      declare -i r=$( expr $r + 1 )
      echo "Nice. Setting this as #1."
      add_1_to_all_existing_ranks
      insertCompletionMessageAndDisplay
      exit 1;
    fi
  elif [[ $answer == "no" ]]; then
    declare -i r=$( expr $r + 1 )
    currentRankingTitle=$(select_where_ranking_equals_r)
    if [[ $r -gt $worstRankVar ]]; then
      echo "Nice. Setting this as your worst rank."
      add_1_to_all_existing_ranks
      insertCompletionMessageAndDisplay
      exit 1;
    fi


    setWorseRankPlusOne
    while [[ r -lt $worstRankPlusOne && $currentRankingTitle != '' ]]; do
      if [[ $rankingTitleBeforeNo == $currentRankingTitle ]]; then
        break
      fi
      echo -n "Is" $t "worse than" $currentRankingTitle "? (yes or no) "
      read answer
      if [[ $answer == "yes" ]]; then
        declare -i r=$( expr $r + 1 )
        currentRankingTitle=$(select_where_ranking_equals_r)
      elif [[ $answer == "no" ]]; then
        break
      else echo "please enter yes or no, you silly person."
      fi
    done

    if [[ $currentRankingTitle == '' ]]; then
      echo "Whoa. You ranked this last???"
      echo "Setting this as your worst rank."
      add_1_to_all_existing_ranks
      insertCompletionMessageAndDisplay
      exit 1;
    fi

    break
  else echo "please enter yes or no, you silly person."
  fi
done



if [[ $currentRankingTitle == '' ]]; then
  echo "Whoa. You ranked this last???"
  declare -i r=$count
  currentRankingTitle=$(select_where_ranking_equals_r)
  while [[ r -gt 0 ]]; do
    worstRankVar=$(worstRank)
    echo -n "Is" $t "better than" $currentRankingTitle "? (yes or no) "
    read answer
    if [[ $answer == "yes" ]]; then
      declare -i r=$( expr $r - 1 )
      currentRankingTitle=$(select_where_ranking_equals_r)
      if [[ $r == 0 ]]; then
        declare -i r=$( expr $r + 1 )
        echo "Nice. Setting this as #1."
        add_1_to_all_existing_ranks
        insertCompletionMessageAndDisplay
        exit 1;
      fi
    elif [[ $answer == "no" ]]; then
      declare -i r=$( expr $r + 1 )
      currentRankingTitle=$(select_where_ranking_equals_r)
      if [[ $r -gt $worstRankVar ]]; then
        echo "Nice. Setting this as your worst rank."
        add_1_to_all_existing_ranks
        insertCompletionMessageAndDisplay
        exit 1;
      fi
      break
    else echo "please enter yes or no, you silly person."
    fi
  done

  setWorseRankPlusOne
  while [[ r -lt $worstRankPlusOne ]]; do
    echo -n "Is" $t "worse than" $currentRankingTitle "? (yes or no) "
    read answer
    if [[ $answer == "yes" ]]; then
      declare -i r=$( expr $r + 1 )
      currentRankingTitle=$(select_where_ranking_equals_r)
    elif [[ $answer == "no" ]]; then
      break
    else echo "please enter yes or no, you silly person."
    fi
  done
fi


echo "Nice. Doing some DB work now..."
add_1_to_all_existing_ranks
insertCompletionMessageAndDisplay
