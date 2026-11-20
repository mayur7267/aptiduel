// Direct and indirect speech, and active and passive voice
// (scripts/generate-verbal.ts).

// Reported speech. One line per sentence:
//   kind|level|direct words|reported part|wrong;wrong;wrong
// kind says how it is reported: "said" (He said, "..." → He said that ...),
// "told" (He said to me, "..." → He told me that ...), "asked" (questions)
// or an instruction verb (told, requested, advised). {he} {his} {him} are
// the speaker's pronouns, {city} a city. The reported part follows the
// speaker's name. Every wrong form breaks a rule of reported speech: no
// change of tense, the wrong pronoun, a time or place word left as it was,
// question word order kept, or the wrong reporting verb.
export const SPEECH = `
said|1|I am tired.|said that {he} was tired|said that {he} is tired;said that I was tired;said that was {he} tired
said|2|I am going to {city} tomorrow.|said that {he} was going to {city} the next day|said that {he} is going to {city} the next day;said that {he} was going to {city} tomorrow;said that I was going to {city} the next day
said|2|I have finished my work.|said that {he} had finished {his} work|said that {he} has finished {his} work;said that I had finished my work;said that {he} had finished my work
said|2|I can solve this problem.|said that {he} could solve that problem|said that {he} can solves this problem;said that I could solve that problem;said that {he} could solved that problem
said|3|I bought a new phone yesterday.|said that {he} had bought a new phone the previous day|said that {he} had bought a new phone yesterday;said that {he} has bought a new phone the previous day;said that I had bought a new phone the previous day
said|2|I live here.|said that {he} lived there|said that {he} lives here;said that {he} lived here;said that I lived there
said|1|I am reading a novel.|said that {he} was reading a novel|said that {he} is reading a novel;said that I was reading a novel;said that {he} had reading a novel
told|2|I will help you.|told me that {he} would help me|told me that {he} will helps me;told me that {he} would help you;told me that I would help {him}
said|1|My brother is a doctor.|said that {his} brother was a doctor|said that {his} brother is a doctor;said that my brother was a doctor;said that {his} brother has a doctor
said|2|We are leaving now.|said that they were leaving then|said that they are leaving now;said that we were leaving then;said that they were leaving now
said|2|I don't like coffee.|said that {he} did not like coffee|said that {he} does not likes coffee;said that I did not like coffee;said that {he} not liked coffee
said|3|I was ill last week.|said that {he} had been ill the previous week|said that {he} is ill the previous week;said that I had been ill the previous week;said that {he} had been ill last week
asked|2|Where do you live?|asked me where I lived|asked me where do I live;asked me where did I live;told me where I lived
asked|2|Are you coming to the party?|asked me if I was coming to the party|asked me that was I coming to the party;asked me if you were coming to the party;told me if I was coming to the party
asked|2|What is your name?|asked me what my name was|asked me what was my name;asked me what your name was;asked me that what my name was
asked|3|Did you see the match?|asked me if I had seen the match|asked me did I see the match;asked me if you had seen the match;asked me that I had seen the match
asked|2|Why are you late?|asked me why I was late|asked me why was I late;asked me why you were late;asked me that why I was late
asked|2|Can you help me?|asked me if I could help {him}|asked me could I help {him};asked me if I could help me;asked me that I could help {him}
asked|2|How old are you?|asked me how old I was|asked me how old was I;asked me how old you were;asked me that how old I was
order|2|Close the door.|told me to close the door|told me that close the door;told me close the door;said me to close the door
request|3|Please lend me your pen.|requested me to lend {him} my pen|requested me to lend me your pen;requested me that lend {him} my pen;told me please lend {him} my pen
order|2|Don't make a noise.|told me not to make a noise|told me don't make a noise;told me not make a noise;said me not to make a noise
order|1|Sit down.|told me to sit down|told me sit down;said me to sit down;told me that sit down
request|3|Please wait here.|requested me to wait there|requested me to wait here;requested me that wait there;said me to wait there
advise|2|Work hard.|advised me to work hard|advised me work hard;advised me that work hard;said me to work hard
`;

// Active and passive voice. Verbs: base|he form|past|past participle|-ing|object|objects
export const VERBS = `
write|writes|wrote|written|writing|a letter|letters
paint|paints|painted|painted|painting|the wall|the walls
clean|cleans|cleaned|cleaned|cleaning|the room|the rooms
repair|repairs|repaired|repaired|repairing|the car|the cars
cook|cooks|cooked|cooked|cooking|a meal|the meals
sign|signs|signed|signed|signing|the form|the forms
deliver|delivers|delivered|delivered|delivering|the parcel|the parcels
open|opens|opened|opened|opening|the window|the windows
plant|plants|planted|planted|planting|a tree|trees
solve|solves|solved|solved|solving|the problem|the problems
check|checks|checked|checked|checking|the answer sheet|the answer sheets
wash|washes|washed|washed|washing|the shirt|the plates
bake|bakes|baked|baked|baking|a cake|cakes
draw|draws|drew|drawn|drawing|a picture|pictures
invite|invites|invited|invited|inviting|the guest|the guests
build|builds|built|built|building|a house|houses
sing|sings|sang|sung|singing|a song|songs
teach|teaches|taught|taught|teaching|the lesson|the lessons
catch|catches|caught|caught|catching|the ball|the thieves
prepare|prepares|prepared|prepared|preparing|the report|the reports
send|sends|sent|sent|sending|an email|emails
read|reads|read|read|reading|the newspaper|the newspapers
`;

// Who does it: subject|after "by"|person (3 = he/she/it, 1 = I, p = we/they)
export const DOERS = `
Ravi|Ravi|3
The teacher|the teacher|3
She|her|3
He|him|3
They|them|p
We|us|p
I|me|1
My mother|my mother|3
The company|the company|3
Priya|Priya|3
`;
