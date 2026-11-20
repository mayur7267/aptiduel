// The vocabulary bank behind Synonyms and Antonyms (scripts/generate-verbal.ts).
//
// One line per word:  word|pos|axis|level|meaning|synonyms|antonyms
//   pos    a (adjective), v (verb), n (noun): options always share it
//   axis   the idea the word sits on, with + or - for its side (qty+ is
//          "a lot", qty- is "too little"). A wrong option for a synonym
//          question is never taken from the same axis, so a near-synonym
//          can't sneak in as a "wrong" answer.
//   level  1 easy, 2 medium, 3 hard
// Synonyms and antonyms are listed closest first.

export const WORDS = `
abundant|a|qty+|1|existing in large amounts|plentiful,ample,copious|scarce,sparse
scarce|a|qty-|1|not enough to meet the need|scant,insufficient,meagre|plentiful,abundant
sparse|a|qty-|2|thinly scattered|scattered,thin,scanty|dense,thick
copious|a|qty+|2|large in quantity|profuse,plentiful,abundant|scanty,meagre
meagre|a|qty-|2|lacking in quantity or quality|scanty,paltry,inadequate|ample,plentiful
paltry|a|qty-|3|very small or meagre|trifling,meagre,measly|substantial,considerable
ample|a|qty+|1|enough or more than enough|plentiful,sufficient,abundant|insufficient,inadequate
substantial|a|qty+|2|of considerable size or amount|considerable,significant,large|negligible,meagre
enormous|a|size+|1|very large|huge,immense,gigantic|tiny,minute
immense|a|size+|1|extremely large|vast,huge,massive|tiny,small
colossal|a|size+|2|extremely large|gigantic,massive,mammoth|minuscule,tiny
diminutive|a|size-|2|extremely small|tiny,minute,petite|huge,enormous
minuscule|a|size-|3|extremely tiny|minute,tiny,microscopic|enormous,huge
vast|a|size+|1|of very great extent|immense,extensive,boundless|tiny,limited
trivial|a|imp-|1|of little value or importance|insignificant,petty,minor|important,significant
significant|a|imp+|1|important enough to be noticed|important,notable,considerable|trivial,insignificant
paramount|a|imp+|3|more important than anything else|supreme,foremost,chief|minor,secondary
negligible|a|imp-|2|so small it can be ignored|insignificant,trifling,minor|significant,considerable
crucial|a|imp+|1|extremely important|vital,critical,essential|unimportant,trivial
frivolous|a|imp-|3|not serious or sensible|silly,flippant,trivial|serious,sensible
benevolent|a|kind+|2|well-meaning and kind|kind,charitable,generous|malevolent,cruel
compassionate|a|kind+|1|showing concern for others' suffering|sympathetic,caring,humane|cruel,heartless
generous|a|kind+|1|ready to give freely|liberal,charitable,bountiful|stingy,miserly
malevolent|a|kind-|3|wishing harm to others|malicious,spiteful,vicious|benevolent,kind
cruel|a|kind-|1|causing pain without caring|brutal,ruthless,heartless|kind,merciful
callous|a|kind-|3|showing no concern for others|heartless,insensitive,unfeeling|caring,sympathetic
hostile|a|kind-|1|unfriendly and aggressive|unfriendly,antagonistic,belligerent|friendly,cordial
cordial|a|kind+|2|warm and friendly|friendly,genial,affable|hostile,unfriendly
amiable|a|kind+|2|friendly and pleasant|affable,genial,good-natured|unfriendly,hostile
stingy|a|kind-|2|unwilling to spend or give|miserly,tight-fisted,penny-pinching|generous,liberal
courageous|a|brave+|1|not deterred by danger|brave,bold,fearless|cowardly,timid
audacious|a|brave+|3|willing to take bold risks|daring,bold,fearless|timid,cautious
timid|a|brave-|1|lacking courage or confidence|shy,fearful,meek|bold,brave
cowardly|a|brave-|1|lacking courage|fearful,faint-hearted,spineless|brave,courageous
valiant|a|brave+|2|showing great courage|heroic,gallant,brave|cowardly,fearful
intrepid|a|brave+|3|fearless and adventurous|fearless,dauntless,bold|timid,fearful
astute|a|smart+|3|clever at understanding situations|shrewd,sharp,perceptive|naive,dull
shrewd|a|smart+|2|having sharp practical judgement|astute,clever,canny|naive,foolish
sagacious|a|smart+|3|wise and having good judgement|wise,judicious,shrewd|foolish,unwise
naive|a|smart-|2|lacking experience or judgement|innocent,gullible,unsophisticated|shrewd,worldly
obtuse|a|smart-|3|slow to understand|dull,dense,slow-witted|sharp,astute
erudite|a|smart+|3|having great knowledge from study|learned,scholarly,knowledgeable|ignorant,illiterate
ignorant|a|smart-|1|lacking knowledge|uninformed,unaware,unenlightened|knowledgeable,learned
gullible|a|smart-|2|easily deceived|credulous,naive,trusting|sceptical,suspicious
prudent|a|care+|2|acting with care and good judgement|wise,careful,sensible|reckless,rash
judicious|a|care+|3|having or showing good judgement|wise,prudent,sensible|foolish,imprudent
meticulous|a|care+|2|showing great attention to detail|careful,thorough,painstaking|careless,sloppy
cautious|a|care+|1|careful to avoid danger|careful,wary,vigilant|reckless,rash
vigilant|a|care+|2|watchful for danger|watchful,alert,attentive|careless,negligent
reckless|a|care-|1|heedless of danger|rash,careless,heedless|cautious,careful
negligent|a|care-|2|failing to take proper care|careless,lax,remiss|careful,attentive
rash|a|care-|2|acting without thinking|hasty,impulsive,reckless|cautious,prudent
impetuous|a|care-|3|acting quickly without thought|impulsive,hasty,rash|cautious,careful
diligent|a|work+|2|showing care and effort in work|industrious,hard-working,assiduous|lazy,idle
industrious|a|work+|2|hard-working|diligent,busy,energetic|lazy,indolent
indolent|a|work-|3|wanting to avoid activity|lazy,idle,slothful|industrious,diligent
lethargic|a|work-|2|sluggish and lacking energy|sluggish,listless,inactive|energetic,lively
energetic|a|work+|1|full of energy|lively,vigorous,active|lethargic,sluggish
idle|a|work-|1|not working or active|inactive,lazy,unoccupied|busy,active
candid|a|truth+|2|truthful and straightforward|frank,open,outspoken|evasive,guarded
sincere|a|truth+|1|free from pretence|genuine,honest,earnest|insincere,false
frank|a|truth+|1|open and direct in speech|candid,blunt,forthright|evasive,secretive
deceitful|a|truth-|2|tending to cheat or mislead|dishonest,false,treacherous|honest,truthful
hypocritical|a|truth-|3|pretending to have virtues one lacks|insincere,two-faced,sanctimonious|sincere,genuine
fraudulent|a|truth-|2|obtained by deception|dishonest,deceitful,bogus|genuine,honest
authentic|a|truth+|2|genuine, not a copy|genuine,real,original|fake,counterfeit
spurious|a|truth-|3|false or fake|fake,false,counterfeit|genuine,authentic
lucid|a|clear+|2|expressed clearly|clear,intelligible,coherent|confusing,obscure
ambiguous|a|clear-|2|open to more than one meaning|unclear,vague,equivocal|clear,definite
vague|a|clear-|1|not clearly expressed|unclear,hazy,indistinct|clear,precise
explicit|a|clear+|2|stated clearly and in detail|clear,precise,specific|implicit,vague
obscure|a|clear-|2|not clearly understood or known|unclear,vague,cryptic|clear,obvious
coherent|a|clear+|2|logical and consistent|logical,consistent,orderly|incoherent,confused
cryptic|a|clear-|3|having a hidden meaning|mysterious,enigmatic,puzzling|clear,plain
transparent|a|clear+|2|easy to see through or understand|clear,see-through,obvious|opaque,murky
verbose|a|talk+|3|using more words than needed|wordy,long-winded,prolix|concise,brief
concise|a|talk-|2|brief but complete|brief,succinct,terse|wordy,verbose
loquacious|a|talk+|3|very talkative|talkative,garrulous,chatty|reticent,taciturn
taciturn|a|talk-|3|saying little|reserved,reticent,uncommunicative|talkative,loquacious
eloquent|a|talk+|2|fluent and persuasive in speech|articulate,expressive,fluent|inarticulate,halting
reticent|a|talk-|3|not revealing one's thoughts readily|reserved,quiet,restrained|open,talkative
temporary|a|time-|1|lasting for a short time|brief,passing,short-lived|permanent,lasting
permanent|a|time+|1|lasting for ever|lasting,enduring,perpetual|temporary,transient
transient|a|time-|3|lasting only briefly|fleeting,momentary,passing|permanent,enduring
ephemeral|a|time-|3|lasting a very short time|fleeting,transient,short-lived|permanent,lasting
perennial|a|time+|3|lasting a long time|enduring,perpetual,constant|temporary,fleeting
incessant|a|time+|3|continuing without pause|ceaseless,continuous,unending|intermittent,occasional
intermittent|a|time-|3|occurring at irregular intervals|sporadic,irregular,occasional|continuous,constant
ancient|a|age+|1|belonging to the very distant past|old,antique,archaic|modern,new
obsolete|a|age+|2|no longer in use|outdated,outmoded,defunct|current,modern
contemporary|a|age-|2|belonging to the present time|modern,current,present-day|ancient,old-fashioned
novel|a|age-|2|new and unusual|new,original,innovative|old,familiar
archaic|a|age+|3|very old or old-fashioned|ancient,antiquated,outdated|modern,current
arduous|a|hard+|3|involving great effort|difficult,strenuous,laborious|easy,effortless
strenuous|a|hard+|2|requiring great effort|arduous,demanding,taxing|easy,effortless
intricate|a|hard+|2|very complicated or detailed|complex,complicated,elaborate|simple,plain
facile|a|hard-|3|too simple or easily achieved|easy,effortless,simplistic|difficult,complex
feasible|a|poss+|2|possible and practical to do|viable,practicable,achievable|impossible,impractical
inevitable|a|poss+|2|certain to happen|unavoidable,inescapable,certain|avoidable,uncertain
plausible|a|poss+|2|seeming reasonable or probable|credible,believable,reasonable|implausible,unlikely
absurd|a|poss-|2|wildly unreasonable|ridiculous,preposterous,ludicrous|sensible,reasonable
serene|a|calm+|2|calm and peaceful|tranquil,peaceful,placid|agitated,turbulent
tranquil|a|calm+|2|free from disturbance|calm,peaceful,serene|noisy,turbulent
placid|a|calm+|3|not easily upset|calm,composed,unruffled|excitable,agitated
turbulent|a|calm-|2|full of disorder or disturbance|stormy,chaotic,tumultuous|calm,peaceful
irate|a|calm-|3|extremely angry|furious,enraged,livid|calm,pleased
furious|a|calm-|1|extremely angry|enraged,irate,livid|calm,pleased
composed|a|calm+|2|having one's feelings under control|calm,collected,poised|agitated,flustered
jubilant|a|joy+|3|feeling great happiness and triumph|joyful,elated,exultant|dejected,sad
elated|a|joy+|2|extremely happy|overjoyed,ecstatic,thrilled|depressed,dejected
melancholy|a|joy-|3|deeply sad|sad,gloomy,sorrowful|cheerful,happy
dejected|a|joy-|2|sad and depressed|downcast,despondent,disheartened|cheerful,elated
cheerful|a|joy+|1|noticeably happy|happy,jolly,merry|gloomy,sad
gloomy|a|joy-|1|dark or sad|dismal,dreary,depressing|bright,cheerful
dismal|a|joy-|2|gloomy or depressing|dreary,bleak,cheerless|bright,cheerful
optimistic|a|hope+|1|hopeful about the future|hopeful,positive,confident|pessimistic,gloomy
pessimistic|a|hope-|2|expecting the worst|gloomy,negative,cynical|optimistic,hopeful
humble|a|pride-|1|having a modest view of oneself|modest,meek,unassuming|proud,arrogant
arrogant|a|pride+|1|having an exaggerated sense of one's importance|haughty,conceited,proud|humble,modest
haughty|a|pride+|3|arrogantly superior|arrogant,proud,disdainful|humble,modest
modest|a|pride-|1|not boasting about one's abilities|humble,unassuming,unpretentious|boastful,arrogant
conceited|a|pride+|2|excessively proud of oneself|vain,arrogant,boastful|modest,humble
pompous|a|pride+|3|showing self-importance|self-important,pretentious,bombastic|modest,humble
fragile|a|strong-|1|easily broken|delicate,brittle,breakable|sturdy,strong
sturdy|a|strong+|1|strongly built|robust,strong,solid|fragile,flimsy
robust|a|strong+|2|strong and healthy|sturdy,vigorous,hardy|weak,frail
frail|a|strong-|2|weak and delicate|weak,feeble,infirm|strong,robust
feeble|a|strong-|2|lacking strength|weak,frail,faint|strong,powerful
resilient|a|strong+|2|able to recover quickly|tough,hardy,adaptable|fragile,vulnerable
vulnerable|a|strong-|2|exposed to harm|defenceless,exposed,susceptible|protected,invulnerable
formidable|a|strong+|3|inspiring fear or respect through power|daunting,powerful,intimidating|weak,feeble
tenacious|a|persist+|3|holding firmly to a purpose|persistent,determined,resolute|irresolute,yielding
persistent|a|persist+|1|continuing firmly despite difficulty|tenacious,determined,dogged|irresolute,wavering
obstinate|a|persist+|2|stubbornly refusing to change one's mind|stubborn,headstrong,unyielding|flexible,compliant
resolute|a|persist+|2|admirably determined|determined,firm,steadfast|irresolute,hesitant
fickle|a|persist-|3|changing frequently|unpredictable,capricious,inconstant|constant,loyal
hesitant|a|persist-|1|unsure or slow to act|uncertain,reluctant,indecisive|decisive,confident
indecisive|a|persist-|2|unable to make decisions|hesitant,irresolute,uncertain|decisive,resolute
reluctant|a|will-|2|unwilling and hesitant|unwilling,hesitant,averse|eager,willing
eager|a|will+|1|strongly wanting to do something|keen,enthusiastic,avid|reluctant,indifferent
voluntary|a|will+|2|done of one's own free will|optional,willing,unforced|compulsory,forced
compulsory|a|will-|2|required by law or rule|mandatory,obligatory,required|optional,voluntary
apathetic|a|will-|3|showing no interest or enthusiasm|indifferent,uninterested,unconcerned|enthusiastic,eager
immaculate|a|clean+|3|perfectly clean|spotless,pristine,flawless|dirty,filthy
filthy|a|clean-|1|very dirty|dirty,grimy,squalid|clean,spotless
pristine|a|clean+|3|in its original perfect condition|immaculate,unspoilt,spotless|dirty,spoilt
squalid|a|clean-|3|extremely dirty and unpleasant|filthy,sordid,seedy|clean,pleasant
affluent|a|rich+|2|having a lot of money|wealthy,prosperous,rich|poor,needy
prosperous|a|rich+|2|successful and wealthy|affluent,thriving,flourishing|poor,struggling
destitute|a|rich-|3|extremely poor|penniless,impoverished,needy|wealthy,rich
impoverished|a|rich-|2|made very poor|poor,needy,destitute|rich,wealthy
lavish|a|spend+|2|rich, generous and costly|luxurious,extravagant,sumptuous|meagre,frugal
frugal|a|spend-|2|sparing with money|thrifty,economical,sparing|extravagant,wasteful
extravagant|a|spend+|2|spending too much|wasteful,lavish,spendthrift|frugal,thrifty
lenient|a|strict-|2|merciful or tolerant|tolerant,forgiving,permissive|strict,harsh
stringent|a|strict+|3|strict and precise|strict,rigorous,exacting|lenient,lax
rigid|a|strict+|2|unable to bend or be changed|stiff,inflexible,firm|flexible,pliable
flexible|a|strict-|1|able to bend or adapt|pliable,adaptable,supple|rigid,stiff
austere|a|strict+|3|severe or strict in manner|severe,stern,strict|indulgent,lenient
ubiquitous|a|spread+|3|present everywhere|omnipresent,pervasive,universal|rare,scarce
pervasive|a|spread+|3|spreading widely through something|widespread,prevalent,ubiquitous|limited,rare
prevalent|a|spread+|2|widespread|common,widespread,rife|rare,uncommon
rare|a|spread-|1|not occurring often|uncommon,unusual,infrequent|common,frequent
hazardous|a|safe-|2|risky or dangerous|dangerous,perilous,risky|safe,harmless
perilous|a|safe-|3|full of danger|dangerous,hazardous,risky|safe,secure
benign|a|safe+|3|gentle and not harmful|harmless,mild,gentle|harmful,malignant
innocuous|a|safe+|3|not harmful or offensive|harmless,inoffensive,safe|harmful,offensive
lethal|a|safe-|2|able to cause death|deadly,fatal,mortal|harmless,safe
fortunate|a|luck+|1|lucky|lucky,blessed,favoured|unlucky,unfortunate
auspicious|a|luck+|3|suggesting future success|favourable,promising,propitious|inauspicious,ominous
ominous|a|luck-|3|suggesting something bad will happen|threatening,menacing,sinister|promising,auspicious
exquisite|a|beauty+|3|extremely beautiful and delicate|beautiful,lovely,elegant|ugly,crude
hideous|a|beauty-|2|extremely ugly|ugly,repulsive,grotesque|beautiful,attractive
graceful|a|grace+|1|moving in a smooth, elegant way|elegant,poised,fluid|clumsy,awkward
clumsy|a|grace-|1|awkward in movement|awkward,ungainly,lumbering|graceful,nimble
loyal|a|faith+|1|giving firm and constant support|faithful,devoted,steadfast|disloyal,treacherous
treacherous|a|faith-|3|guilty of betrayal|disloyal,traitorous,perfidious|loyal,faithful
steadfast|a|faith+|3|firm and unwavering|loyal,firm,unwavering|wavering,fickle
courteous|a|polite+|2|polite and respectful|polite,civil,gracious|rude,discourteous
rude|a|polite-|1|offensively impolite|impolite,discourteous,insolent|polite,courteous
insolent|a|polite-|3|rude and disrespectful|impudent,rude,disrespectful|respectful,polite
impudent|a|polite-|3|not showing due respect|insolent,cheeky,impertinent|respectful,polite
tactful|a|polite+|2|careful not to offend|diplomatic,discreet,sensitive|tactless,blunt
renowned|a|fame+|2|known and admired by many|famous,celebrated,acclaimed|unknown,unsung
notorious|a|fame-|2|famous for something bad|infamous,disreputable,scandalous|reputable,respected
eminent|a|fame+|3|famous and respected in a field|distinguished,prominent,illustrious|unknown,unsung
identical|a|same+|1|exactly alike|alike,same,indistinguishable|different,dissimilar
analogous|a|same+|3|comparable in some ways|similar,comparable,parallel|different,unlike
diverse|a|same-|2|showing a great deal of variety|varied,assorted,mixed|uniform,homogeneous
adroit|a|skill+|3|clever or skilful|skilful,deft,adept|clumsy,inept
proficient|a|skill+|2|competent and skilled|skilled,adept,expert|incompetent,inept
inept|a|skill-|3|lacking skill|incompetent,bungling,unskilled|skilful,competent
competent|a|skill+|1|having the necessary ability|capable,able,qualified|incompetent,inept
conceal|v|hide+|1|to keep from being seen or known|hide,cover,mask|reveal,disclose
reveal|v|hide-|1|to make known|disclose,divulge,expose|conceal,hide
disclose|v|hide-|2|to make information known|reveal,divulge,uncover|conceal,withhold
divulge|v|hide-|3|to reveal a secret|disclose,reveal,leak|conceal,suppress
expand|v|grow+|1|to become larger|enlarge,extend,swell|contract,shrink
diminish|v|grow-|2|to make or become smaller|decrease,reduce,lessen|increase,enlarge
augment|v|grow+|3|to make greater by adding|increase,enhance,boost|decrease,reduce
dwindle|v|grow-|3|to become gradually smaller|decline,shrink,wane|grow,increase
amplify|v|grow+|2|to increase the volume or strength|magnify,intensify,boost|reduce,diminish
curtail|v|grow-|3|to reduce or cut short|reduce,restrict,cut back|extend,expand
flourish|v|grow+|2|to grow or develop well|thrive,prosper,bloom|wither,decline
wither|v|grow-|2|to become dry and shrivelled|wilt,shrivel,fade|flourish,thrive
accelerate|v|speed+|2|to move or happen faster|quicken,hasten,speed up|decelerate,slow down
hasten|v|speed+|2|to hurry or make happen sooner|hurry,expedite,quicken|delay,slow down
delay|v|speed-|1|to make late or slow|postpone,defer,hold up|hasten,expedite
procrastinate|v|speed-|3|to keep delaying something that must be done|delay,postpone,dawdle|act,proceed
reject|v|agree-|1|to refuse to accept|refuse,decline,dismiss|accept,approve
accept|v|agree+|1|to agree to take or receive|receive,welcome,approve|reject,refuse
approve|v|agree+|1|to officially agree to|sanction,endorse,authorise|reject,disapprove
endorse|v|agree+|2|to declare public support for|support,back,approve|oppose,reject
oppose|v|agree-|1|to disagree with and resist|resist,contest,challenge|support,endorse
deny|v|agree-|1|to state that something is not true|refute,contradict,dispute|admit,confirm
confirm|v|agree+|1|to establish the truth of|verify,affirm,corroborate|deny,refute
refute|v|agree-|3|to prove to be false|disprove,rebut,negate|confirm,prove
corroborate|v|agree+|3|to support with evidence|confirm,verify,substantiate|refute,contradict
praise|v|praise+|1|to express approval or admiration|commend,applaud,acclaim|criticise,condemn
commend|v|praise+|2|to praise formally|praise,applaud,laud|criticise,censure
exalt|v|praise+|3|to praise highly or raise in rank|glorify,extol,elevate|degrade,humiliate
condemn|v|praise-|2|to express strong disapproval of|denounce,criticise,censure|praise,commend
criticise|v|praise-|1|to point out faults in|condemn,censure,disparage|praise,commend
censure|v|praise-|3|to express severe disapproval of|condemn,rebuke,reprimand|praise,commend
admonish|v|praise-|3|to warn or reprimand firmly|reprimand,rebuke,scold|praise,commend
humiliate|v|praise-|2|to make someone feel ashamed|embarrass,shame,degrade|honour,dignify
abandon|v|keep-|1|to leave behind completely|desert,forsake,leave|keep,retain
retain|v|keep+|2|to continue to have|keep,hold,preserve|lose,discard
discard|v|keep-|2|to get rid of|throw away,dispose of,scrap|keep,retain
preserve|v|keep+|2|to keep safe or unchanged|protect,conserve,maintain|destroy,damage
squander|v|keep-|3|to waste foolishly|waste,fritter away,misuse|save,conserve
abolish|v|begin-|2|to formally put an end to|eliminate,end,scrap|establish,create
establish|v|begin+|1|to set up on a firm basis|found,set up,create|abolish,dissolve
initiate|v|begin+|2|to cause to begin|start,launch,commence|end,conclude
commence|v|begin+|2|to begin|start,begin,launch|end,finish
terminate|v|begin-|2|to bring to an end|end,stop,conclude|begin,start
cease|v|begin-|2|to come to an end|stop,end,halt|continue,begin
eradicate|v|begin-|3|to destroy completely|eliminate,wipe out,stamp out|establish,introduce
assist|v|help+|1|to help|help,aid,support|hinder,obstruct
facilitate|v|help+|3|to make easier|ease,enable,assist|hinder,obstruct
hinder|v|help-|2|to create difficulties for|obstruct,hamper,impede|help,assist
impede|v|help-|3|to delay or block progress|obstruct,hinder,hamper|help,facilitate
obstruct|v|help-|2|to block or get in the way of|block,hinder,impede|clear,assist
alleviate|v|relief+|3|to make suffering less severe|relieve,ease,lessen|aggravate,worsen
mitigate|v|relief+|3|to make less severe|lessen,reduce,alleviate|intensify,aggravate
aggravate|v|relief-|3|to make worse|worsen,intensify,exacerbate|alleviate,relieve
exacerbate|v|relief-|3|to make a problem worse|worsen,aggravate,intensify|alleviate,ease
comprehend|v|know+|2|to understand fully|understand,grasp,follow|misunderstand,misinterpret
elucidate|v|know+|3|to make clear|explain,clarify,illuminate|confuse,obscure
clarify|v|know+|1|to make clearer|explain,elucidate,simplify|confuse,complicate
perplex|v|know-|3|to puzzle or confuse|baffle,bewilder,confuse|clarify,enlighten
bewilder|v|know-|2|to confuse completely|baffle,perplex,confuse|enlighten,clarify
deteriorate|v|qual-|3|to become worse|worsen,decline,degenerate|improve,recover
ameliorate|v|qual+|3|to make better|improve,enhance,better|worsen,aggravate
enhance|v|qual+|2|to improve the quality of|improve,boost,enrich|diminish,reduce
scrutinise|v|care+|3|to examine closely|examine,inspect,study|ignore,overlook
heed|v|care+|3|to pay attention to|mind,obey,follow|ignore,disregard
neglect|v|care-|2|to fail to care for|ignore,disregard,overlook|attend to,look after
overlook|v|care-|2|to fail to notice|miss,ignore,neglect|notice,heed
provoke|v|calm-|2|to deliberately make angry|anger,incite,irritate|pacify,calm
pacify|v|calm+|3|to make calm|calm,soothe,appease|provoke,anger
soothe|v|calm+|2|to gently calm|calm,comfort,pacify|agitate,irritate
unite|v|join+|1|to join together|join,combine,unify|separate,divide
integrate|v|join+|2|to combine into a whole|combine,merge,unify|separate,segregate
assemble|v|join+|2|to gather together|gather,collect,convene|disperse,scatter
segregate|v|join-|3|to set apart from others|separate,isolate,divide|integrate,unite
disperse|v|join-|3|to scatter in different directions|scatter,spread,dispel|gather,assemble
acquire|v|get+|2|to obtain|obtain,gain,procure|lose,forfeit
forfeit|v|get-|3|to lose as a penalty|lose,surrender,sacrifice|gain,acquire
relinquish|v|get-|3|to give up willingly|surrender,give up,renounce|retain,keep
deplete|v|stock-|3|to use up the supply of|exhaust,drain,use up|replenish,refill
replenish|v|stock+|3|to fill up again|refill,restock,renew|deplete,exhaust
prolong|v|len+|2|to extend in time|extend,lengthen,protract|shorten,curtail
abbreviate|v|len-|2|to shorten|shorten,abridge,condense|lengthen,expand
scarcity|n|qty-|2|a shortage|shortage,dearth,lack|abundance,plenty
abundance|n|qty+|2|a very large quantity|plenty,profusion,wealth|scarcity,shortage
dearth|n|qty-|3|a lack of something|scarcity,shortage,paucity|abundance,plenty
affluence|n|rich+|3|wealth|wealth,prosperity,riches|poverty,want
poverty|n|rich-|1|the state of being very poor|want,penury,destitution|wealth,affluence
animosity|n|kind-|3|strong hostility|hostility,enmity,antagonism|friendship,goodwill
enmity|n|kind-|3|the state of being enemies|hostility,animosity,antagonism|friendship,amity
amity|n|kind+|3|friendly relations|friendship,harmony,goodwill|enmity,hostility
benevolence|n|kind+|3|kindness|kindness,goodwill,generosity|cruelty,malice
courage|n|brave+|1|the ability to face danger|bravery,valour,boldness|cowardice,fear
cowardice|n|brave-|2|lack of courage|timidity,fearfulness,faint-heartedness|courage,bravery
candour|n|truth+|3|openness and honesty|frankness,honesty,openness|deceit,evasiveness
deceit|n|truth-|2|the act of misleading others|deception,dishonesty,trickery|honesty,candour
fatigue|n|work-|2|extreme tiredness|exhaustion,weariness,tiredness|energy,vigour
vigour|n|work+|2|physical strength and energy|energy,vitality,strength|weakness,lethargy
humility|n|pride-|2|a modest view of one's own importance|modesty,humbleness,meekness|arrogance,pride
arrogance|n|pride+|2|an exaggerated sense of one's importance|conceit,haughtiness,vanity|humility,modesty
anxiety|n|calm-|1|a feeling of worry|worry,unease,nervousness|calmness,serenity
serenity|n|calm+|3|the state of being calm|calmness,tranquillity,peace|anxiety,agitation
victory|n|win+|1|success in a contest|triumph,success,win|defeat,loss
defeat|n|win-|1|a loss in a contest|loss,failure,rout|victory,triumph
zenith|n|top+|3|the highest point|peak,summit,pinnacle|nadir,bottom
apex|n|top+|3|the top or highest point|peak,summit,tip|base,bottom
nadir|n|top-|3|the lowest point|bottom,low point,depths|zenith,peak
chaos|n|order-|2|complete disorder|disorder,confusion,turmoil|order,calm
harmony|n|order+|2|agreement or peaceful order|accord,peace,agreement|discord,conflict
discord|n|order-|3|disagreement between people|conflict,strife,dissension|harmony,agreement
consent|n|agree+|2|permission|permission,approval,assent|refusal,dissent
dissent|n|agree-|3|disagreement with an official view|disagreement,objection,opposition|agreement,consent
novice|n|skill-|2|a person new to an activity|beginner,learner,newcomer|expert,veteran
`;
