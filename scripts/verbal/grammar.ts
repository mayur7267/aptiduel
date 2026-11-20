// Grammar sentences for Fill in the blanks and Spot the error
// (scripts/generate-verbal.ts).
//
// One line per sentence:  topic|level|sentence|right|wrong;wrong;wrong|rule
//   The sentence is in three parts split by " / ", with ___ for the blank.
//   Fill in the blanks shows the whole sentence; Spot the error puts a wrong
//   word in the blank and asks which part is wrong (or "No error").
//   Slots, filled in with different values for each copy:
//     {m} {m2} a man's name, {f} a woman's name, {city}, {year}, {n} a
//     number of years, {clock}, {day}, {month}, {pl} a plural group.
// Every wrong option is wrong in that sentence, not just less usual.

export const GRAMMAR = `
Prepositions|1|{m} has been living / in {city} ___ / {year}.|since|for;from;by|"Since" marks a point in time; "for" marks a length of time.
Prepositions|1|{f} has been working / at this company ___ / {n} years.|for|since;from;by|"For" is used with a length of time; "since" with a point in time.
Prepositions|1|The exam starts / ___ {clock} / sharp.|at|on;in;of|We use "at" with clock times.
Prepositions|1|The festival falls / ___ {day} / this year.|on|in;at;of|We use "on" with days and dates.
Prepositions|1|{m} was born / ___ {month} / {year}.|in|on;at;of|We use "in" with months and years.
Prepositions|2|{f} is good / ___ mathematics / and science.|at|in;on;with|We say "good at" a subject or skill.
Prepositions|2|{m} is senior / ___ me / in the office.|to|than;from;over|"Senior", "junior", "superior" and "inferior" take "to", not "than".
Prepositions|2|I prefer walking / ___ running / in the morning.|to|than;by;from|We "prefer" one thing "to" another.
Prepositions|2|{f} insisted / ___ paying / for the dinner.|on|for;at;to|We say "insist on" doing something.
Prepositions|2|Please refrain / ___ talking / during the lecture.|from|to;of;with|We say "refrain from".
Prepositions|1|{m} has always been / afraid ___ / dogs.|of|from;with;by|We say "afraid of".
Prepositions|1|{f} is very interested / ___ classical music / and dance.|in|on;at;for|We say "interested in".
Prepositions|2|The success of the plan / depends ___ / teamwork.|on|in;of;at|We say "depend on".
Prepositions|2|{m} was accused / ___ theft / by his employer.|of|for;with;about|We say "accused of" a crime.
Prepositions|3|{m} was charged / ___ murder / by the police.|with|of;for;about|We say "charged with" a crime.
Prepositions|2|The committee consists / ___ seven members / from different states.|of|from;in;with|We say "consist of".
Prepositions|2|{f} is proud / ___ her achievements / in sport.|of|on;for;at|We say "proud of".
Prepositions|2|{m} is capable / ___ handling / the project alone.|of|for;in;to|We say "capable of" doing something.
Prepositions|2|We were not aware / ___ the change / in the rules.|of|about;with;from|We say "aware of".
Prepositions|1|{f} is responsible / ___ the accounts / of the shop.|for|of;to;with|We say "responsible for" something.
Prepositions|3|{m} congratulated {f} / ___ her success / in the exam.|on|for;at;with|We "congratulate" someone "on" something.
Prepositions|2|{f} has been suffering / ___ asthma / for years.|from|of;at;by|We say "suffer from" an illness.
Prepositions|2|{m} is jealous / ___ his cousin's / success.|of|from;on;with|We say "jealous of".
Prepositions|2|The film is based / ___ a true story / from the war.|on|in;at;from|We say "based on".
Prepositions|2|{f} is familiar / ___ this software / already.|with|to;for;in|A person is "familiar with" something.
Prepositions|1|The box was full / ___ old letters / and photographs.|of|with;by;in|We say "full of".
Prepositions|3|Many members abstained / ___ voting / on the bill.|from|of;to;with|We say "abstain from".
Prepositions|3|The new rule deprived / the workers ___ / their bonus.|of|from;with;for|We "deprive" someone "of" something.
Prepositions|1|{m} is fond / ___ reading / detective novels.|of|in;with;for|We say "fond of".
Prepositions|2|{f} was angry / ___ her brother / for breaking the vase.|with|on;to;of|We are "angry with" a person.
Prepositions|2|{m} is superior / ___ his rivals / in skill.|to|than;from;over|"Superior" takes "to", not "than".
Prepositions|2|{f} has no objection / ___ your / proposal.|to|for;on;with|We say "objection to".
Prepositions|1|We will meet / ___ the evening / after work.|in|on;at;of|We say "in the evening".
Agreement|2|Each of the {pl} / ___ a new kit / for the match.|has|have;are having;were having|After "each of", the verb is singular.
Agreement|2|One of my friends / ___ a doctor / in {city}.|is|are;were;have been|After "one of" and a plural noun, the verb is singular.
Agreement|2|Neither {m} nor his friends / ___ ready / for the trip.|are|is;was;has been|With "neither ... nor", the verb agrees with the nearer subject.
Agreement|2|Either the students or the teacher / ___ responsible / for the mess.|is|are;were;have been|With "either ... or", the verb agrees with the nearer subject.
Agreement|2|{m}, as well as his brothers, / ___ coming / to the party.|is|are;were;have|The verb agrees with the first subject; "as well as" does not change it.
Agreement|2|The number of applicants / ___ increasing / every year.|is|are;were;have|"The number of" takes a singular verb.
Agreement|2|A number of students / ___ absent / today.|are|is;was;has been|"A number of" means "many" and takes a plural verb.
Agreement|3|Bread and butter / ___ my favourite / breakfast.|is|are;were;have been|"Bread and butter" is one dish, so the verb is singular.
Agreement|2|Mathematics / ___ my favourite / subject.|is|are;were;have been|"Mathematics" is singular.
Agreement|2|The news / ___ very surprising / to everyone.|was|were;are;have been|"News" is singular.
Agreement|3|Neither of the two answers / ___ correct / in this test.|is|are;were;have been|"Neither of" takes a singular verb.
Agreement|2|Ten kilometres / ___ a long distance / to walk.|is|are;were;have been|A distance taken as one amount takes a singular verb.
Agreement|1|{f} and her sister / ___ going / to {city}.|are|is;was;has|Two subjects joined by "and" take a plural verb.
Agreement|2|Everyone in the class / ___ finished / the test.|has|have;are;were|"Everyone" takes a singular verb.
Agreement|3|The scissors / ___ on the table / near the window.|are|is;was;has|"Scissors" is plural.
Agreement|2|The furniture / in this room / ___ expensive.|is|are;were;have been|"Furniture" is uncountable and takes a singular verb.
Agreement|2|The quality of these mangoes / ___ very good / this year.|is|are;were;have been|The verb agrees with "quality", not with "mangoes".
Tenses|2|If it ___ tomorrow, / we will stay / at home.|rains|will rain;rained;had rained|In a first conditional the "if" clause takes the present tense.
Tenses|2|If I ___ rich, / I would travel / around the world.|were|am;will be;had been|In an unreal present condition we use "were".
Tenses|3|If you had studied harder, / you ___ / passed.|would have|will have;would;had|A third conditional takes "would have" and the past participle.
Tenses|2|By the time we reached the station, / the train ___ / already.|had left|has left;leaves;will leave|The earlier of two past actions takes the past perfect.
Tenses|1|{f} ___ to the gym / every / morning.|goes|go;going;gone|A habit takes the simple present.
Tenses|1|Look! / The children ___ / in the garden.|are playing|play;played;have played|An action happening right now takes the present continuous.
Tenses|2|{m} ___ / in {city} since / {year}.|has lived|lives;lived;is living|An action from a past point up to now takes the present perfect.
Tenses|2|I ___ {m} / at the market / yesterday.|met|have met;meet;will meet|"Yesterday" takes the simple past.
Tenses|2|While I ___ dinner, / the lights / went out.|was cooking|am cooking;cook;have cooked|A longer past action interrupted by another takes the past continuous.
Tenses|2|{f} ___ her homework / before her friends / arrived.|had finished|has finished;finishes;will finish|The earlier of two past actions takes the past perfect.
Tenses|2|Next year, / {m} ___ / his degree.|will complete|completed;has completed;had completed|A future action takes "will".
Tenses|3|The train / ___ at 6 pm / every day.|leaves|is leaving;has left;had left|A fixed routine takes the simple present.
Tenses|3|I wish / I ___ / the answer.|knew|know;will know;have known|After "I wish" about the present, we use the past tense.
Tenses|3|It is high time / we ___ / home.|left|leave;will leave;have left|"It is high time" is followed by the past tense.
Tenses|2|{f} ___ for two hours / when the bus / finally came.|had been waiting|has been waiting;is waiting;waits|An action that went on until a past moment takes the past perfect continuous.
Tenses|1|The sun / ___ / in the east.|rises|rose;is rising;has risen|A universal truth takes the simple present.
Tenses|2|We ___ the match / if we had / practised more.|would have won|will win;would win;won|A third conditional takes "would have" and the past participle.
Verb forms|2|{m} is used to / ___ / early.|getting up|get up;got up;gets up|"Be used to" is followed by the -ing form.
Verb forms|2|I look forward / to ___ / you soon.|meeting|meet;met;have met|"Look forward to" is followed by the -ing form.
Verb forms|2|{f} avoided / ___ / the question.|answering|to answer;answer;answered|"Avoid" is followed by the -ing form.
Verb forms|2|They decided / ___ / early.|to leave|leaving;leave;left|"Decide" is followed by "to" and a verb.
Verb forms|1|{m} enjoys / ___ cricket / on Sundays.|playing|to play;play;played|"Enjoy" is followed by the -ing form.
Verb forms|2|{f} made her brother / ___ / the dishes.|wash|to wash;washing;washed|"Make someone" is followed by the base verb.
Verb forms|2|Would you mind / ___ / the window?|closing|to close;close;closed|"Mind" is followed by the -ing form.
Verb forms|2|{f} let her son / ___ / the car.|drive|to drive;driving;drove|"Let someone" is followed by the base verb.
Verb forms|2|{m} suggested / ___ / a taxi.|taking|to take;take;took|"Suggest" is followed by the -ing form.
Verb forms|2|{f} is too tired / ___ / any further.|to walk|walking;walk;walked|"Too" and an adjective are followed by "to" and a verb.
Verb forms|3|{m} could not help / ___ / at the joke.|laughing|to laugh;laugh;laughed|"Cannot help" is followed by the -ing form.
Verb forms|2|The teacher asked us / ___ / quiet.|to keep|keeping;keep;kept|"Ask someone" is followed by "to" and a verb.
Comparison|1|{m} is / ___ than / his brother.|taller|tallest;more taller;tall|Comparing two takes the comparative.
Comparison|1|This is the ___ book / I have / ever read.|best|better;good;most best|"The" with "ever" takes the superlative.
Comparison|2|{f} is the ___ / of the two / sisters.|elder|eldest;elderly;most elder|For two people in a family we use "elder".
Comparison|2|Gold is ___ / than / silver.|more expensive|expensiver;most expensive;expensive|Long adjectives form the comparative with "more".
Comparison|3|{f} is ___ intelligent / as / her brother.|as|so;more;most|"As ... as" compares two equal things.
Comparison|2|This road is / ___ / of all the roads in the city.|the widest|wider;more wide;most widest|Comparing more than two takes the superlative.
Comparison|2|Of the two plans, / this one is / ___.|better|best;more better;good|Comparing two takes the comparative.
Articles|1|___ sun rises / in the east / every morning.|The|A;An;No article|We use "the" with things that are one of a kind.
Articles|2|___ Ganga is / a holy river / in India.|The|A;An;No article|Names of rivers take "the".
Articles|2|___ Himalayas are / the highest mountains / in the world.|The|A;An;No article|Names of mountain ranges take "the".
Articles|2|___ honesty is / the best / policy.|No article|The;A;An|An abstract noun used in a general sense takes no article.
Articles|2|___ Indian Ocean / is warm / in summer.|The|A;An;No article|Names of oceans take "the".
Question tags|1|{f} is a doctor / at the city hospital, / ___?|isn't she|is she;doesn't she;wasn't she|A positive sentence takes a negative tag with the same helping verb.
Question tags|1|{m} can swim / across the river, / ___?|can't he|can he;doesn't he;won't he|A positive sentence takes a negative tag with the same helping verb.
Question tags|2|Let's go / for a walk, / ___?|shall we|will we;don't we;shan't we|"Let's" takes the tag "shall we".
Question tags|2|Nobody / called me today, / ___?|did they|didn't they;did he;have they|"Nobody" makes the sentence negative, so the tag is positive.
Question tags|2|I am late / for the meeting, / ___?|aren't I|amn't I;isn't I;don't I|"I am" takes the tag "aren't I".
Question tags|1|{m} didn't come / to class yesterday, / ___?|did he|didn't he;does he;has he|A negative sentence takes a positive tag.
Question tags|2|{f} has finished / her project, / ___?|hasn't she|has she;didn't she;doesn't she|A positive sentence takes a negative tag with the same helping verb.
Question tags|2|There is a bank / near your house, / ___?|isn't there|is there;isn't it;doesn't it|"There is" takes the tag "isn't there".
Question tags|2|{m} never / tells lies, / ___?|does he|doesn't he;is he;isn't he|"Never" makes the sentence negative, so the tag is positive.
Question tags|1|They were / at home last night, / ___?|weren't they|were they;didn't they;aren't they|A positive sentence takes a negative tag with the same helping verb.
Question tags|2|{f} hardly / eats anything, / ___?|does she|doesn't she;is she;isn't she|"Hardly" makes the sentence negative, so the tag is positive.
Conjunctions|2|No sooner had {m} reached the station / ___ the train / left.|than|when;then;before|"No sooner" is followed by "than".
Conjunctions|2|Hardly had {f} sat down / ___ the phone / rang.|when|than;then;that|"Hardly" is followed by "when".
Conjunctions|2|{m} is not only intelligent / ___ / hard-working.|but also|and also;as well as;or also|"Not only" is followed by "but also".
Conjunctions|2|Walk carefully / lest you ___ / on the ice.|should fall|will fall;would fall;might not fall|"Lest" is followed by "should" and a verb.
Conjunctions|2|Though {f} worked hard, / ___ she / failed.|yet|but;and;so|"Though" pairs with "yet", never with "but".
Conjunctions|2|Both {m} ___ {m2} / were selected / for the team.|and|as well as;or;nor|"Both" pairs with "and".
Conjunctions|2|Either you finish the work / ___ you / leave.|or|nor;and;but|"Either" pairs with "or".
Conjunctions|2|Neither {m} ___ {f} / attended / the meeting.|nor|or;and;but|"Neither" pairs with "nor".
Conjunctions|3|Scarcely had the match started / ___ it began / to rain.|when|than;then;that|"Scarcely" is followed by "when".
Conjunctions|2|{f} waited / ___ the bus / arrived.|until|unless;since;if|"Until" means "up to the time when".
Conjunctions|2|You will fail / ___ you / work hard.|unless|until;if;when|"Unless" means "if not".
Pronouns|2|Between you / and ___, / this plan will not work.|me|I;myself;mine|After a preposition like "between", we use the object form "me".
Pronouns|2|{m} and ___ / went / to the market.|I|me;myself;mine|As part of the subject, we use "I".
Pronouns|1|This book / on the table / is ___.|mine|my;me;I|"Mine" stands on its own without a noun.
Pronouns|2|The teacher praised / {m} and ___ / for our project.|me|I;myself;mine|As the object of a verb, we use "me".
Pronouns|2|{m} hurt ___ / while playing / football.|himself|him;his;hisself|When the subject and the object are the same person, we use a reflexive pronoun.
Pronouns|2|{f} and ___ / are / best friends.|I|me;myself;mine|As part of the subject, we use "I".
`;

export const SLOTS: Record<string, string[]> = {
  m: ['Ravi', 'Arjun', 'Karan', 'Rahul', 'Vikram', 'Aditya', 'Rohan', 'Sameer', 'Nikhil', 'Manish'],
  m2: ['Suresh', 'Deepak', 'Amit', 'Varun', 'Harsh', 'Kunal'],
  f: ['Priya', 'Neha', 'Ananya', 'Sneha', 'Pooja', 'Meera', 'Kavya', 'Divya', 'Riya', 'Asha'],
  city: ['Pune', 'Chennai', 'Jaipur', 'Kochi', 'Indore', 'Nagpur', 'Lucknow', 'Mysuru', 'Bhopal', 'Surat'],
  year: ['2015', '2016', '2017', '2018', '2019', '2020', '2021'],
  n: ['two', 'three', 'four', 'five', 'six', 'ten'],
  clock: ['9 am', '10 am', '11:30 am', '2 pm', '3:30 pm'],
  day: ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'],
  month: ['March', 'June', 'August', 'October', 'December'],
  pl: ['players', 'students', 'workers', 'girls', 'boys'],
};
