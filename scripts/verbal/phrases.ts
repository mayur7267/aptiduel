// One-word substitutions, idioms and phrasal verbs (scripts/generate-verbal.ts).

// phrase|word|group|level. Wrong options come from the same group, so they
// look alike but each one means something else.
export const ONE_WORD = `
One who does not believe in God|Atheist|person|1
One who is not sure whether God exists|Agnostic|person|2
One who believes that everything is decided by fate|Fatalist|person|2
One who looks on the bright side of things|Optimist|person|1
One who always expects the worst|Pessimist|person|1
One who hates mankind|Misanthrope|person|3
One who loves mankind and gives generously to good causes|Philanthropist|person|2
One who hates women|Misogynist|person|3
One who abstains from marriage|Celibate|person|3
One who knows everything|Omniscient|person|2
One who is present everywhere|Omnipresent|person|2
One who is all-powerful|Omnipotent|person|2
One who eats too much|Glutton|person|2
One who eats human flesh|Cannibal|person|2
One who collects stamps|Philatelist|person|3
One who collects coins|Numismatist|person|3
One who walks in sleep|Somnambulist|person|3
One who talks in sleep|Somniloquist|person|3
One who speaks many languages|Polyglot|person|2
One who can use both hands equally well|Ambidextrous|person|3
One who is new to a profession or activity|Novice|person|1
One who lives alone and avoids company|Recluse|person|3
One who leaves one's own country to settle in another|Emigrant|person|2
One who comes into a foreign country to settle there|Immigrant|person|2
One who flees to another country for safety|Refugee|person|1
One who betrays one's country|Traitor|person|1
One who gives blood or an organ to save others|Donor|person|1
One who pretends to be someone else to deceive others|Impostor|person|2
One who loves books|Bibliophile|person|3
One who is an expert judge in matters of taste|Connoisseur|person|3
One who dies for a cause|Martyr|person|1
One who is under the legal age of adulthood|Minor|person|1
One who works without pay|Volunteer|person|1
One who travels on foot|Pedestrian|person|1
One who runs away from justice|Fugitive|person|2
One who is extremely poor|Pauper|person|2
One who lives at the expense of others|Parasite|person|2
One who insists on everything being perfect|Perfectionist|person|1
One who remains calm and unmoved by pleasure or pain|Stoic|person|3
One who loves and defends his country|Patriot|person|1
One who is unable to pay his debts|Insolvent|person|3
One who wants to overthrow all government|Anarchist|person|2
One who is opposed to war|Pacifist|person|2
One who believes in many gods|Polytheist|person|3
One who believes in only one God|Monotheist|person|3
Government by the people|Democracy|govt|1
Government by one person with absolute power|Autocracy|govt|2
Government by the rich|Plutocracy|govt|3
Government by religious leaders|Theocracy|govt|3
Government by a small group of powerful people|Oligarchy|govt|3
Government by officials rather than elected representatives|Bureaucracy|govt|2
Government by a king or queen|Monarchy|govt|1
A state with no government at all|Anarchy|govt|2
Government by a privileged class of nobles|Aristocracy|govt|3
Government by old people|Gerontocracy|govt|3
The study of birds|Ornithology|study|3
The study of insects|Entomology|study|3
The study of human history through objects dug from the ground|Archaeology|study|2
The study of the mind and behaviour|Psychology|study|1
The study of earthquakes|Seismology|study|3
The study of the origin of words|Etymology|study|3
The study of handwriting|Graphology|study|3
The study of human societies and cultures|Anthropology|study|2
The study of plants|Botany|study|1
The study of animals|Zoology|study|1
The study of stars and planets|Astronomy|study|1
The study of the earth's rocks and structure|Geology|study|1
The study of diseases|Pathology|study|2
The study of old age|Gerontology|study|3
The study of weather|Meteorology|study|2
The study of the skin and its diseases|Dermatology|study|2
The study of family history|Genealogy|study|3
The science of making maps|Cartography|study|3
The study of sound|Acoustics|study|2
Fear of water|Hydrophobia|fear|2
Fear of heights|Acrophobia|fear|3
Fear of closed spaces|Claustrophobia|fear|2
Fear of open or crowded public places|Agoraphobia|fear|3
Fear or dislike of foreigners|Xenophobia|fear|3
Fear of spiders|Arachnophobia|fear|3
Fear of darkness|Nyctophobia|fear|3
Fear of fire|Pyrophobia|fear|3
Killing of one's father|Patricide|kill|2
Killing of one's mother|Matricide|kill|2
Killing of one's brother|Fratricide|kill|3
Killing of one's sister|Sororicide|kill|3
Killing of an infant|Infanticide|kill|2
Killing of oneself|Suicide|kill|1
Killing of a king|Regicide|kill|3
Deliberate killing of a whole race or community|Genocide|kill|2
Killing of one human being by another|Homicide|kill|2
A place where bees are kept|Apiary|place|3
A place where birds are kept|Aviary|place|2
A tank where fish are kept|Aquarium|place|1
A place where dead bodies are kept for a time|Mortuary|place|2
A place where weapons are stored|Arsenal|place|2
A home for children without parents|Orphanage|place|1
A place where coins are made|Mint|place|2
A place where grain is stored|Granary|place|2
A building where horses are kept|Stable|place|1
A place where monks live|Monastery|place|1
A place where nuns live|Convent|place|2
A place where beer is made|Brewery|place|2
A place where animals are killed for meat|Abattoir|place|3
A place where old records are kept|Archives|place|2
A place where dead people are buried|Cemetery|place|1
A place where animal skins are made into leather|Tannery|place|2
A shelter where dogs are kept|Kennel|place|1
A pen where pigs are kept|Sty|place|2
A speech made without preparation|Extempore|words|2
A speech made by a character alone on stage|Soliloquy|words|3
Words written on a tomb|Epitaph|words|3
A section at the end of a book or play|Epilogue|words|2
An introduction to a book or play|Prologue|words|2
A list of books referred to in a work|Bibliography|words|2
A word that reads the same backwards as forwards|Palindrome|words|2
A collection of poems by different writers|Anthology|words|2
The story of a person's life written by that person|Autobiography|words|1
The story of a person's life written by someone else|Biography|words|1
A book or document written by hand|Manuscript|words|2
An imitation of a work made for fun|Parody|words|3
A false name used by a writer|Pseudonym|words|2
A word opposite in meaning to another|Antonym|words|1
A word that means the same as another|Synonym|words|1
A word formed from the first letters of other words|Acronym|words|2
That which cannot be read|Illegible|cannot|2
That which cannot be corrected|Incorrigible|cannot|3
That which cannot be seen|Invisible|cannot|1
That which cannot be avoided|Inevitable|cannot|2
That which cannot be believed|Incredible|cannot|1
That which cannot be heard|Inaudible|cannot|2
That which cannot be cured|Incurable|cannot|1
That which cannot be described in words|Indescribable|cannot|2
That which cannot be destroyed|Indestructible|cannot|1
That which cannot be satisfied|Insatiable|cannot|3
That which cannot be conquered|Invincible|cannot|2
That which cannot be imitated|Inimitable|cannot|3
That which cannot be explained|Inexplicable|cannot|3
That which cannot be passed through or entered|Impenetrable|cannot|3
That which is fit to be eaten|Edible|other|1
That which happens every year|Annual|other|1
That which happens every two years|Biennial|other|3
That which happens twice a year|Biannual|other|3
That which happens every hundred years|Centennial|other|3
That which is done of one's own free will|Voluntary|other|1
That which lasts for a very short time|Ephemeral|other|3
A cure for all diseases or problems|Panacea|other|3
A substance that kills germs to prevent infection|Antiseptic|other|2
A group of ships|Fleet|group|1
A group of stars forming a pattern|Constellation|group|2
A group of cattle|Herd|group|1
A group of sheep|Flock|group|1
A group of wolves|Pack|group|1
A large group of flying insects|Swarm|group|1
A group of lions|Pride|group|2
A large group of fish swimming together|Shoal|group|2
A group of singers|Choir|group|1
A group of islands|Archipelago|group|2
A bunch of flowers|Bouquet|group|1
`;

// idiom|meaning|level|sense. Two idioms with the same sense are never
// offered against each other.
export const IDIOMS = `
a blessing in disguise|something good that seemed bad at first|1|
add fuel to the fire|make a bad situation worse|1|worse
at the drop of a hat|immediately, without hesitation|2|
back to square one|back to the starting point|1|
barking up the wrong tree|blaming or pursuing the wrong thing|2|
beat around the bush|avoid getting to the point|1|
bite off more than one can chew|take on more than one can handle|2|
break a leg|good luck (said before a performance)|2|
by the skin of one's teeth|only just; narrowly|2|
cry over spilt milk|regret something that cannot be undone|1|
cut corners|do something cheaply or carelessly to save effort|2|
easier said than done|harder to do than to talk about|1|
every cloud has a silver lining|there is something good in every bad situation|1|
get cold feet|become nervous and back out|2|
give someone the cold shoulder|deliberately ignore someone|2|ignore
go the extra mile|make more effort than is expected|1|effort
hit the sack|go to bed|2|
in hot water|in trouble|1|
keep one's fingers crossed|hope for a good outcome|1|
kill two birds with one stone|achieve two aims with one action|1|
let the cat out of the bag|reveal a secret by mistake|1|
miss the boat|lose an opportunity by being too slow|2|
on cloud nine|extremely happy|1|happy
over the moon|delighted|2|happy
on the same page|in agreement|1|agree
see eye to eye|agree fully|1|agree
out of the blue|unexpectedly|1|
pull someone's leg|tease someone playfully|1|joke
tongue in cheek|not meant seriously|3|joke
sit on the fence|avoid taking sides|2|
take it with a pinch of salt|not believe it completely|2|
the ball is in your court|it is your turn to act|2|
the last straw|the final problem that makes a situation unbearable|2|
throw in the towel|admit defeat|2|
turn a blind eye|pretend not to notice|1|ignore
up in the air|undecided|2|
a hot potato|a controversial issue that is hard to handle|3|
a red herring|something that misleads or distracts|3|
an Achilles' heel|a weak point|3|
the apple of one's eye|a person loved very much|1|
at sixes and sevens|in a state of confusion|3|
bell the cat|take on a risky task for the common good|3|
blow one's own trumpet|boast about oneself|2|
bury the hatchet|make peace|2|
burn the candle at both ends|exhaust oneself by doing too much|3|
by leaps and bounds|very rapidly|2|
call a spade a spade|speak frankly|2|
cut no ice|have no influence|3|
a cat and dog life|a life of constant quarrels|2|conflict
at loggerheads|in strong disagreement|3|conflict
bad blood|hostility between people|2|conflict
crocodile tears|false sorrow|2|
an axe to grind|a selfish or private purpose|3|
a white elephant|a costly possession that is of no use|3|
a wild goose chase|a hopeless search|2|
at one's wits' end|completely unsure what to do next|2|
bear the brunt|suffer the main force of something|3|
between the devil and the deep sea|between two equally bad choices|2|
a black sheep|a disgraced member of a family or group|1|
blue blood|noble birth|3|
bring home the bacon|earn a living|3|
by hook or by crook|by any means, fair or unfair|2|
a chip off the old block|a person very like their parent|2|
cool one's heels|be kept waiting|3|
cut and dried|already decided|3|
a dog in the manger|a person who stops others using what he cannot use himself|3|
draw the line|set a limit|2|
eat humble pie|admit a mistake and apologise|3|
face the music|accept the consequences of one's actions|2|
a feather in one's cap|an achievement to be proud of|2|
a fish out of water|someone uncomfortable in a new situation|1|
a flash in the pan|a sudden success that does not last|3|
straight from the horse's mouth|from the original source|2|
get the sack|be dismissed from a job|2|
give up the ghost|die|3|
hand in glove|working closely together, often in wrongdoing|3|
hang by a thread|be in a very risky state|2|
have a bee in one's bonnet|be obsessed with an idea|3|
head over heels|completely in love|2|
hold one's horses|wait and be patient|2|
in black and white|in writing|2|
in the nick of time|just in time|1|
in a nutshell|in brief|1|
keep the wolf from the door|have just enough to avoid hunger|3|
leave no stone unturned|try every possible way|1|effort
let sleeping dogs lie|avoid stirring up an old problem|2|
the lion's share|the largest part|2|
make both ends meet|live within one's income|2|
nip in the bud|stop something at an early stage|2|
null and void|having no legal force|3|
odds and ends|small miscellaneous items|2|
on the cards|likely to happen|3|
once bitten, twice shy|cautious after a bad experience|2|
out of the woods|out of danger|2|
pay through the nose|pay far too much|2|
play second fiddle|take a less important role|2|lesser
take a back seat|choose a less active role|2|lesser
put the cart before the horse|do things in the wrong order|2|
rain cats and dogs|rain very heavily|1|
read between the lines|understand the hidden meaning|1|
rest on one's laurels|stop trying after early success|3|
rub salt into the wound|make someone's pain worse|2|worse
run amok|behave wildly and uncontrollably|3|
smell a rat|suspect that something is wrong|2|
spick and span|neat and clean|2|
steal the show|attract the most attention|2|
a storm in a teacup|a big fuss about a small matter|2|
strike while the iron is hot|act at the right moment|1|
take the bull by the horns|face a difficulty directly|2|
throw cold water on|discourage an idea or plan|2|
tie the knot|get married|1|
to the letter|exactly as instructed|2|
turn over a new leaf|start behaving better|2|improve
pull one's socks up|make an effort to improve|2|improve
under one's thumb|completely controlled by someone|2|
walk on eggshells|be very careful not to offend|2|
water under the bridge|past events that no longer matter|2|
when pigs fly|never|2|
a wolf in sheep's clothing|an enemy pretending to be a friend|2|
with flying colours|with great success|1|
yeoman's service|very useful service|3|
a fair-weather friend|a friend only in good times|2|
a bed of roses|an easy, comfortable situation|2|
all ears|listening eagerly|1|
a stone's throw|a short distance|1|
come to terms with|accept a difficult situation|2|
down to earth|practical and realistic|1|
get the hang of|learn how to do something|2|
hit the roof|become very angry|2|angry
see red|become very angry|2|angry
in the same boat|in the same difficult situation|1|
jump on the bandwagon|join a popular trend|2|
keep an eye on|watch carefully|1|
let off steam|release strong feelings|2|
put one's foot down|be firm about something|2|
the tip of the iceberg|a small part of a bigger problem|2|
through thick and thin|in good times and bad|2|
twist someone's arm|persuade someone to do something|2|
under the table|secretly and illegally|2|
a wet blanket|a person who spoils others' fun|3|
`;

// form|meaning|sentence|level|sense: the phrasal verb as used in the
// sentence, and a meaning that can replace it there. All sentences are in
// the past, so the tense of an option gives nothing away.
export const PHRASAL = `
called off|cancelled|The organisers called off the match because of rain.|1|
put off|postponed|They put off the meeting until Friday.|1|
looked after|took care of|She looked after her grandmother all summer.|1|
gave up|stopped trying|He gave up after three failed attempts.|1|quit
gave in|yielded|The parents finally gave in and bought the toy.|2|quit
broke down|stopped working|The bus broke down on the highway.|1|
ran out of|had no more of|We ran out of milk this morning.|1|deplete
used up|consumed completely|We used up all the paper in the printer.|1|deplete
came across|found by chance|I came across an old photo in the drawer.|1|chance
ran into|met by chance|I ran into an old friend at the station.|1|chance
looked into|investigated|The police looked into the complaint.|2|examine
looked over|examined quickly|The manager looked over the report before lunch.|2|examine
went over|reviewed|She went over her notes before the exam.|2|examine
turned down|rejected|She turned down the job offer.|1|
brought up|raised|His uncle brought him up after his parents died.|2|
set up|established|They set up a small company in 2020.|1|
put up with|tolerated|She put up with the noise for months.|2|
got over|recovered from|He got over the flu in a week.|1|recover
pulled through|survived a serious illness|The patient pulled through after the surgery.|3|recover
took after|resembled|She took after her mother in looks.|2|
carried out|performed|The team carried out the experiment carefully.|2|
pointed out|drew attention to|The teacher pointed out the mistake.|1|
found out|discovered|We found out the truth later.|1|
went through|experienced|The family went through a difficult time.|2|
made up|invented|He made up an excuse for being late.|2|
looked up|searched for|I looked up the word in a dictionary.|1|
turned up|arrived|Only ten people turned up for the talk.|2|
broke out|started suddenly|A fire broke out in the kitchen.|1|
backed out|withdrew from a commitment|He backed out of the deal at the last minute.|2|
called on|visited briefly|We called on our neighbours last evening.|3|
fell out|quarrelled|The two friends fell out over money.|2|
held up|delayed|Heavy traffic held us up for an hour.|2|
kept up with|stayed level with|She kept up with the leaders throughout the race.|2|
let down|disappointed|He let his team down by missing practice.|1|
made out|managed to see|We made out a faint light in the distance.|2|
passed away|died|His grandfather passed away last year.|1|
put out|extinguished|The firemen put out the fire quickly.|1|
showed off|displayed proudly to impress others|He showed off his new phone to everyone.|1|
stood by|supported|Her friends stood by her during the trial.|2|
took over|took control of|A larger firm took over the company.|2|
took up|started (a hobby)|She took up painting after retirement.|1|
told off|scolded|The coach told off the players for being late.|2|
wore out|became unusable through use|His shoes wore out after a year.|2|
worked out|found the answer to|We finally worked out the puzzle.|2|resolve
sorted out|resolved|They sorted out the problem quickly.|1|resolve
ironed out|settled|The two sides ironed out their differences.|3|resolve
called for|required|The situation called for quick action.|2|
came up with|thought of|She came up with a clever plan.|1|idea
put forward|proposed|She put forward a new idea at the meeting.|2|idea
cut down on|reduced|He cut down on sugar to stay healthy.|1|
dropped out|left without finishing|He dropped out of college in his second year.|2|
filled in|completed|I filled in the application form.|1|
got along|had a friendly relationship|The new roommates got along well.|1|
handed in|submitted|The students handed in their assignments.|1|
looked down on|regarded as inferior|He looked down on people who had less money.|2|
looked forward to|waited eagerly for|The children looked forward to the holidays.|1|
looked up to|admired|She looked up to her elder sister.|1|
made up for|compensated for|He made up for his mistake by working late.|2|
set off|started a journey|We set off for Goa at dawn.|1|
turned out|proved|The rumour turned out to be false.|2|
went off|exploded|The bomb went off in an empty building.|2|
brushed up|polished|She brushed up her French before the trip.|2|
called up|telephoned|He called up his mother every Sunday.|1|
cleared up|became bright|The sky cleared up by noon.|2|
died out|became extinct|Dinosaurs died out millions of years ago.|1|
did away with|abolished|The government did away with the old tax.|2|
fell through|failed to happen|Our holiday plans fell through.|2|
got by|managed to survive|They got by on a small income.|2|
kept off|stayed away from|The children kept off the wet floor.|2|
laid off|dismissed|The factory laid off two hundred workers.|2|
put across|communicated clearly|She put across her ideas well in the interview.|3|
ran over|hit with a vehicle|The car ran over a snake on the road.|2|
saw off|said goodbye to at the point of departure|We saw him off at the airport.|2|
set aside|saved for a purpose|She set aside money for her studies.|2|
stood out|was easily noticed|Her red dress stood out in the crowd.|1|
took off|left the ground|The plane took off on time.|1|
wiped out|destroyed completely|The flood wiped out the village.|2|
broke into|entered by force|Thieves broke into the shop at night.|1|
called in|summoned|The company called in an expert.|3|
came down with|fell ill with|She came down with fever last week.|2|
counted on|relied on|We counted on him for support.|2|
dealt with|handled|She dealt with the complaint politely.|2|
fell behind|failed to keep up|He fell behind in his studies.|2|
got rid of|threw away|We got rid of the old sofa.|1|
headed for|moved towards|The ship headed for the port.|2|
jotted down|wrote quickly|I jotted down her phone number.|2|
kept on|continued|He kept on talking during the film.|1|
looked back on|remembered|She looked back on her school days with joy.|2|
mixed up|confused|I mixed up the two names.|1|
opted out|chose not to take part|Three members opted out of the scheme.|2|
owned up|confessed|He owned up to breaking the window.|2|
passed out|fainted|She passed out in the heat.|2|
picked up|learned without formal lessons|He picked up French while living in Paris.|2|
played down|made seem less important|The minister played down the problem.|3|
ruled out|excluded as a possibility|The doctors ruled out an infection.|2|
stepped down|resigned|The chairman stepped down last month.|2|
summed up|summarised|The teacher summed up the lesson.|2|
thought over|considered carefully|She thought over the offer for a week.|2|
tried out|tested|We tried out the new software.|1|
turned into|became|The caterpillar turned into a butterfly.|1|
broke off|ended|The two countries broke off talks.|2|
brought about|caused|The new law brought about many changes.|2|
came about|happened|The change came about slowly.|2|
gave away|revealed|His smile gave away the surprise.|2|
`;
