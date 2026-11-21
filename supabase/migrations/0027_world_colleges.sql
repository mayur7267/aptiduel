-- 0027: colleges from all over the world, found with a search box.
--
-- Most reel views now come from outside India, so the 144 Indian colleges
-- grow to about 34,000 in 224 countries:
--   ROR, the Research Organization Registry (https://ror.org, CC0): every
--   active organisation of type "education". City names are GeoNames'
--   (CC BY 4.0).
--   Hipo's university-domains-list (MIT): universities ROR doesn't list.
-- The rows themselves are imported from colleges-world.csv after this file
-- runs (Table Editor → colleges → Insert → Import data from CSV); see
-- scripts/colleges/README.md.
--
-- The existing colleges keep their ids and names (players use them); 121
-- of them get ROR's id, full name and aliases, so "Indian Institute of
-- Technology Bombay" finds "IIT Bombay".
--
-- Apps search with search_colleges(); a missing college can be added with
-- add_college(). Older apps that still load the whole table see only the
-- colleges in use, not 34,000 rows (see the policy below).

create extension if not exists pg_trgm with schema extensions;
create extension if not exists unaccent with schema extensions;

alter table public.colleges
  add column if not exists country    text,
  add column if not exists ror_id     text,
  add column if not exists aliases    text,
  add column if not exists domains    text,
  add column if not exists source     text not null default 'apticks',
  add column if not exists weight     smallint not null default 0,
  add column if not exists added_by   uuid references auth.users (id) on delete set null,
  add column if not exists created_at timestamptz not null default now(),
  add column if not exists search     text not null default '',
  add column if not exists names      text[] not null default '{}';

-- Every college so far is in India, apart from "Other college". They are
-- the ones people play for, so they rank like the best-known colleges.
update public.colleges set country = 'IN' where country is null and source = 'apticks' and name <> 'Other college';
update public.colleges set weight = 2 where source = 'apticks';

-- The same name can be a college in two places.
alter table public.colleges drop constraint if exists colleges_name_key;
create unique index if not exists colleges_place_key
  on public.colleges (lower(name), coalesce(city, ''), coalesce(country, ''));
create unique index if not exists colleges_ror_key on public.colleges (ror_id) where ror_id is not null;

-- Text as search compares it: lower case, no accents, "&" as "and",
-- "R.V." as "rv", any other punctuation as a space.
create or replace function public.college_text(t text) returns text
language sql stable set search_path = '' as $$
  select btrim(regexp_replace(regexp_replace(replace(lower(extensions.unaccent(coalesce(t, ''))), '&', ' and '),
         '[.''’]', '', 'g'), '[^a-z0-9]+', ' ', 'g'))
$$;

create or replace function public.colleges_search() returns trigger
language plpgsql set search_path = '' as $$
begin
  new.search := public.college_text(concat_ws(' ', new.name, new.city, new.aliases, new.domains));
  -- The name and every alias on its own, for exact matches ("mit", "iit bombay").
  new.names := array(select public.college_text(x)
                     from unnest(array[new.name] || string_to_array(coalesce(new.aliases, ''), ' | ')) as x
                     where btrim(x) <> '');
  return new;
end $$;

drop trigger if exists colleges_search on public.colleges;
create trigger colleges_search before insert or update of name, city, aliases, domains on public.colleges
  for each row execute function public.colleges_search();

create index if not exists colleges_search_trgm on public.colleges using gin (search extensions.gin_trgm_ops);

-- The existing colleges ROR also lists (built by scripts/colleges/build_world.py).
update public.colleges set ror_id = '00qzypv28', aliases = 'Vellore Institute of Technology University | Vellore Engineering College | VIT', domains = 'vit.ac.in' where id = 1 and ror_id is null;
update public.colleges set ror_id = '007v4hf75', aliases = 'VIT-AP University | VITAP', domains = 'vitap.ac.in' where id = 3 and ror_id is null;
update public.colleges set ror_id = '02d03ve54', aliases = 'VIT Bhopal University', domains = 'vitbhopal.ac.in' where id = 4 and ror_id is null;
update public.colleges set ror_id = '050113w36', aliases = 'SRM Institute of Science and Technology | Sri Ramaswamy Memorial University', domains = 'srmist.edu.in' where id = 5 and ror_id is null;
update public.colleges set ror_id = '00k8zt527', aliases = 'KIIT University | Kalinga Institute of Industrial Technology', domains = 'kiit.ac.in' where id = 7 and ror_id is null;
update public.colleges set ror_id = '01tez1r52', aliases = 'PSG College of Technology | PSGCT', domains = 'psgtech.edu' where id = 8 and ror_id is null;
update public.colleges set ror_id = '03am10p12', aliases = 'Amrita Vishwa Vidyapeetham | Amrita University, Amrita Vishwa Vidyapeetham University', domains = 'amrita.edu' where id = 10 and ror_id is null;
update public.colleges set ror_id = '032jk8892', aliases = 'SASTRA University | Shanmugha Arts, Science, Technology & Research Academy', domains = 'sastra.edu' where id = 11 and ror_id is null;
update public.colleges set ror_id = '01defpn95', aliases = 'Sathyabama Institute of Science and Technology | Sathyabama Engineering College, Sathyabama University | SIST', domains = 'sathyabama.ac.in' where id = 12 and ror_id is null;
update public.colleges set ror_id = '041re0e60', aliases = 'R.V. College of Engineering | Rashtreeya Vidyalaya College of Engineering | Rāshtrīya Vidyālaya Tāntrika Mahāvidyālaya | RVCE', domains = 'rvce.edu.in' where id = 13 and ror_id is null;
update public.colleges set ror_id = '02g4pvf45', aliases = 'B.M.S. College of Engineering | BMSCE', domains = 'bmsce.ac.in' where id = 14 and ror_id is null;
update public.colleges set ror_id = '05m169e78', aliases = 'PES University | PES Institute of Technology | PES, PESIT', domains = 'pes.edu' where id = 15 and ror_id is null;
update public.colleges set ror_id = '02nyr4y94', aliases = 'Ramaiah Institute of Technology | M. S. Ramaiah Institute of Technology | MSRIT, RIT', domains = 'msrit.edu' where id = 16 and ror_id is null;
update public.colleges set ror_id = '046qksq74', aliases = 'Dayananda Sagar College of Engineering | DSCE', domains = 'dsce.edu.in' where id = 17 and ror_id is null;
update public.colleges set ror_id = '022tv9y30', aliases = 'Christ University | Christ | Christ (Deemed to Be University), Christ College', domains = 'christuniversity.in' where id = 19 and ror_id is null;
update public.colleges set ror_id = '01h4k6h92', aliases = 'Nitte Meenakshi Institute of Technology | NMIT', domains = 'nmit.ac.in' where id = 20 and ror_id is null;
update public.colleges set ror_id = '047x65e68', aliases = 'National Institute of Technology Tiruchirappalli | NIT Trichy | Regional Engineering College | NITT', domains = 'nitt.edu' where id = 21 and ror_id is null;
update public.colleges set ror_id = '017ebfz38', aliases = 'National Institute of Technology Warangal | NIT Warangal | NITW', domains = 'nitw.ac.in' where id = 22 and ror_id is null;
update public.colleges set ror_id = '03yyd7552', aliases = 'National Institute of Technology Calicut | Calicut Regional Engineering College | CREC, NITC', domains = 'nitc.ac.in' where id = 24 and ror_id is null;
update public.colleges set ror_id = '04dp7tp96', aliases = 'Motilal Nehru National Institute of Technology | Motilal Nehru Regional Engineering College | NIT Allahabad | MNNIT, MNREC', domains = 'mnnit.ac.in' where id = 25 and ror_id is null;
update public.colleges set ror_id = '026vtd268', aliases = 'Maulana Azad National Institute of Technology | Maulana Azad College of Technology, National Institute of Technology | MACT, MANIT, NIT', domains = 'manit.ac.in' where id = 26 and ror_id is null;
update public.colleges set ror_id = '02y394t43', aliases = 'Sardar Vallabhbhai National Institute of Technology Surat | NIT Surat | National Institute of Technology, Surat | SVNIT', domains = 'svnit.ac.in' where id = 27 and ror_id is null;
update public.colleges set ror_id = '05f11g639', aliases = 'International Institute of Information Technology, Hyderabad | IIIT Hyderabad | IIIT', domains = 'iiit.ac.in' where id = 28 and ror_id is null;
update public.colleges set ror_id = '002tchr49', aliases = 'Jawaharlal Nehru Technological University, Hyderabad | Nagarjuna Sagar Engineering College | JNTU | JNTUH', domains = 'jntuh.ac.in' where id = 29 and ror_id is null;
update public.colleges set ror_id = '047ymzq84', aliases = 'Chaitanya Bharathi Institute of Technology | CBIT', domains = 'cbit.ac.in' where id = 30 and ror_id is null;
update public.colleges set ror_id = '0440p1d37', aliases = 'GITAM University | GITAM (Deemed to Be University), Gandhi Institute of Technology and Management | GITAM College | GITAM', domains = 'gitam.edu' where id = 32 and ror_id is null;
update public.colleges set ror_id = '008128n17', aliases = 'COEP Technological University | COEP Tech, COEP Technological University Pune, College of Engineering Pune, College of Engineering Pune Technological University, Pune Institute of Engineering and Technology | COEP', domains = 'coeptech.ac.in' where id = 34 and ror_id is null;
update public.colleges set ror_id = '004ymxd45', aliases = 'MIT World Peace University | Dr. Vishwanath Karad MIT World Peace University | MIT-WPU', domains = 'mitwpu.edu.in' where id = 36 and ror_id is null;
update public.colleges set ror_id = '04d4hxn32', aliases = 'Dwarkadas J. Sanghvi College of Engineering | D.J. Sanghvi | DJ', domains = 'djsce.ac.in' where id = 40 and ror_id is null;
update public.colleges set ror_id = '05qkq7x38', aliases = 'Nirma University | Nirma University of Science and Technology | NU', domains = 'nirmauni.ac.in' where id = 41 and ror_id is null;
update public.colleges set ror_id = '01ztcvt22', aliases = 'Delhi Technological University | Delhi College of Engineering | DCE, DTU', domains = 'dtu.ac.in' where id = 43 and ror_id is null;
update public.colleges set ror_id = '01fczmh85', aliases = 'Netaji Subhas University of Technology | Netaji Subhas Institute of Technology | NSIT, NSUT', domains = 'nsut.ac.in' where id = 44 and ror_id is null;
update public.colleges set ror_id = '034q1za58', aliases = 'Guru Gobind Singh Indraprastha University | Indraprastha University | GGSIPU, IPU', domains = 'ipu.ac.in' where id = 45 and ror_id is null;
update public.colleges set ror_id = '05sttyy11', aliases = 'Jaypee Institute of Information Technology | JIIT', domains = 'jiit.ac.in' where id = 46 and ror_id is null;
update public.colleges set ror_id = '02n9z0v62', aliases = 'Amity University | Amity University Noida, Amity University Online, Amity University Uttar Pradesh | AUUP', domains = 'amity.edu amityonline.com' where id = 47 and ror_id is null;
update public.colleges set ror_id = '02w8ba206', aliases = 'Galgotias University | GU', domains = 'galgotiasuniversity.edu.in' where id = 48 and ror_id is null;
update public.colleges set ror_id = '00an5hx75', aliases = 'Bennett University', domains = 'bennett.edu.in' where id = 49 and ror_id is null;
update public.colleges set ror_id = '05aqahr97', aliases = 'Shiv Nadar University | Shiv Nadar Institution of Eminence | SNU', domains = 'snu.edu.in' where id = 50 and ror_id is null;
update public.colleges set ror_id = '00wdq3744', aliases = 'Thapar Institute of Engineering & Technology | Thapar Institute of Engineering and Technology, Thapar University', domains = 'thapar.edu' where id = 51 and ror_id is null;
update public.colleges set ror_id = '05t4pvx35', aliases = 'Chandigarh University | CU', domains = 'cumail.in' where id = 52 and ror_id is null;
update public.colleges set ror_id = '00et6q107', aliases = 'Lovely Professional University', domains = 'lpu.co.in' where id = 53 and ror_id is null;
update public.colleges set ror_id = '04q2jes40', aliases = 'University of Petroleum and Energy Studies | UPES', domains = 'upes.ac.in' where id = 54 and ror_id is null;
update public.colleges set ror_id = '03wqgqd89', aliases = 'Graphic Era University | Graphic Era Institute of Technology | GEIT', domains = 'geu.ac.in' where id = 55 and ror_id is null;
update public.colleges set ror_id = '001p3jz28', aliases = 'Birla Institute of Technology and Science, Pilani | BITS Pilani', domains = '' where id = 56 and ror_id is null;
update public.colleges set ror_id = '02af4h012', aliases = 'Jadavpur University | Université jadavpur', domains = 'jadavpuruniversity.in' where id = 57 and ror_id is null;
update public.colleges set ror_id = '04gbnn054', aliases = 'Heritage Institute of Technology | Heritage Institute of Technology, Kolkata | HITK', domains = 'heritageit.edu' where id = 58 and ror_id is null;
update public.colleges set ror_id = '02qyf5152', aliases = 'Indian Institute of Technology Bombay | Institut indien de technologie de bombay | IIT Bombay | IITB', domains = 'iitb.ac.in' where id = 181 and ror_id is null;
update public.colleges set ror_id = '049tgcd06', aliases = 'Indian Institute of Technology Delhi | Institut indien de technologie de delhi | IIT Delhi | IITD', domains = 'iitd.ac.in' where id = 182 and ror_id is null;
update public.colleges set ror_id = '03v0r5n49', aliases = 'Indian Institute of Technology Madras | IIT Madras | IITM', domains = 'iitm.ac.in' where id = 183 and ror_id is null;
update public.colleges set ror_id = '05pjsgx75', aliases = 'Indian Institute of Technology Kanpur | Institut indien de technologie de kanpur | IIT Kanpur | IITK', domains = 'iitk.ac.in' where id = 184 and ror_id is null;
update public.colleges set ror_id = '03w5sq511', aliases = 'Indian Institute of Technology Kharagpur | IIT Kharagpur | IIT KGP', domains = 'iitkgp.ac.in' where id = 185 and ror_id is null;
update public.colleges set ror_id = '00582g326', aliases = 'Indian Institute of Technology Roorkee | IIT Roorkee | University of Roorkee | IITR', domains = 'iitr.ac.in' where id = 186 and ror_id is null;
update public.colleges set ror_id = '0022nd079', aliases = 'Indian Institute of Technology Guwahati | IIT Guwahati | IITG', domains = 'iitg.ac.in' where id = 187 and ror_id is null;
update public.colleges set ror_id = '01j4v3x97', aliases = 'Indian Institute of Technology Hyderabad | Institut de technologie indien d''hyderabad | IIT Hyderabad | IITH', domains = 'iith.ac.in' where id = 188 and ror_id is null;
update public.colleges set ror_id = '01kh5gc44', aliases = 'Indian Institute of Technology BHU | IIT (BHU), Varanasi | Indian Institute of Technology (Banaras Hindu University), Indian Institute of Technology (Banaras Hindu University) Varanasi | IIT BHU', domains = 'iitbhu.ac.in' where id = 189 and ror_id is null;
update public.colleges set ror_id = '013v3cc28', aliases = 'Indian Institute of Technology Dhanbad | Indian School of Mines | IIT, ISM', domains = 'iitism.ac.in' where id = 190 and ror_id is null;
update public.colleges set ror_id = '01hhf7w52', aliases = 'Indian Institute of Technology Indore | IIT Indore | IITI', domains = 'iiti.ac.in' where id = 191 and ror_id is null;
update public.colleges set ror_id = '02qkhhn56', aliases = 'Indian Institute of Technology Ropar | IIT Ropar | IIT-RPR', domains = 'iitrpr.ac.in' where id = 192 and ror_id is null;
update public.colleges set ror_id = '05r9r2f34', aliases = 'Indian Institute of Technology Mandi | IIT Mandi', domains = 'iitmandi.ac.in' where id = 193 and ror_id is null;
update public.colleges set ror_id = '0036p5w23', aliases = 'Indian Institute of Technology Gandhinagar | iit ni jankari | IIT Gandhinagar | IITGN', domains = 'iitgn.ac.in' where id = 194 and ror_id is null;
update public.colleges set ror_id = '03yacj906', aliases = 'Indian Institute of Technology Jodhpur | AIIMS Jodhpur | IITJ', domains = 'iitj.ac.in' where id = 195 and ror_id is null;
update public.colleges set ror_id = '01ft5vz71', aliases = 'Indian Institute of Technology Patna | IIT Patna | IITP', domains = 'iitp.ac.in' where id = 196 and ror_id is null;
update public.colleges set ror_id = '04gx72j20', aliases = 'Indian Institute of Technology Bhubaneswar | IIT Bhubaneswar', domains = 'iitbbs.ac.in' where id = 197 and ror_id is null;
update public.colleges set ror_id = '01xtkxh20', aliases = 'Indian Institute of Technology Tirupati | IITTP', domains = 'iittp.ac.in' where id = 198 and ror_id is null;
update public.colleges set ror_id = '02f0vsw63', aliases = 'Indian Institute of Technology Jammu | IIT Jammu | IIT', domains = 'iitjammu.ac.in' where id = 200 and ror_id is null;
update public.colleges set ror_id = '0509djg30', aliases = 'Indian Institute of Technology Dharwad | IIT Dharwad', domains = 'iitdh.ac.in' where id = 201 and ror_id is null;
update public.colleges set ror_id = '02sscsx71', aliases = 'Indian Institute of Technology Bhilai | IIT Bhilai', domains = 'iitbhilai.ac.in' where id = 202 and ror_id is null;
update public.colleges set ror_id = '02v7trd43', aliases = 'Indian Institute of Technology Goa | IIT Goa', domains = 'iitgoa.ac.in' where id = 203 and ror_id is null;
update public.colleges set ror_id = '011gmn932', aliases = 'National Institute of Technology Rourkela | REC Rourkela | Regional Engineering College Rourkela | NITR', domains = 'nitrkl.ac.in' where id = 204 and ror_id is null;
update public.colleges set ror_id = '04909p852', aliases = 'National Institute of Technology Kurukshetra | NIT Kurukshetra', domains = 'nitkkr.ac.in' where id = 205 and ror_id is null;
update public.colleges set ror_id = '0077k1j32', aliases = 'Malaviya National Institute of Technology Jaipur | Malaviya Regional Engineering College Jaipur | MNIT', domains = 'mnit.ac.in' where id = 206 and ror_id is null;
update public.colleges set ror_id = '02zrtpp84', aliases = 'Visvesvaraya National Institute of Technology | NIT Nagpur, Regional College of Engineering, Nagpur, Visvesvaraya Regional College of Engineering | VNIT, VRCE', domains = 'vnit.ac.in' where id = 207 and ror_id is null;
update public.colleges set ror_id = '04ds0jm32', aliases = 'National Institute of Technology Durgapur | NIT Durgapur | Regional Engineering College, Durgapur | NITD', domains = 'nitdgp.ac.in' where id = 208 and ror_id is null;
update public.colleges set ror_id = '01sebzx27', aliases = 'National Institute of Technology Jamshedpur | NIT Jamshedpur', domains = 'nitjsr.ac.in' where id = 209 and ror_id is null;
update public.colleges set ror_id = '001ws2a36', aliases = 'National Institute Of Technology Silchar | NIT Silchar | NITS', domains = 'nits.ac.in' where id = 210 and ror_id is null;
update public.colleges set ror_id = '03xt0bg88', aliases = 'Dr. B. R. Ambedkar National Institute of Technology Jalandhar | NIT Jalandhar | NITJ', domains = 'nitj.ac.in' where id = 212 and ror_id is null;
update public.colleges set ror_id = '056wyhh33', aliases = 'National Institute of Technology Patna | Bihar College of Engineering, Bihar School of Engineering | NIT Patna | NITP', domains = 'nitp.ac.in' where id = 213 and ror_id is null;
update public.colleges set ror_id = '02y553197', aliases = 'National Institute of Technology Raipur | Govt. College of Mining & Metallurgy, NIT Raipur', domains = 'nitrr.ac.in' where id = 214 and ror_id is null;
update public.colleges set ror_id = '03sfwvw54', aliases = 'National Institute of Technology Srinagar | NITSRI', domains = 'nitsri.ac.in' where id = 215 and ror_id is null;
update public.colleges set ror_id = '03swyrn62', aliases = 'National Institute of Technology Agartala | NIT Agartala | Tripura Engineering College | NITA', domains = 'nita.ac.in' where id = 216 and ror_id is null;
update public.colleges set ror_id = '032twef21', aliases = 'National Institute of Technology Delhi | NIT Delhi | NITD', domains = 'nitdelhi.ac.in' where id = 217 and ror_id is null;
update public.colleges set ror_id = '01vmfpj79', aliases = 'National Institute of Technology Goa | NITGoa', domains = 'nitgoa.ac.in' where id = 218 and ror_id is null;
update public.colleges set ror_id = '02tare285', aliases = 'National Institute of Technology, Puducherry | NIT Puducherry | NITPY', domains = 'nitpy.ac.in' where id = 219 and ror_id is null;
update public.colleges set ror_id = '05pet6f20', aliases = 'National Institute of Technology Uttarakhand', domains = 'nituk.ac.in' where id = 220 and ror_id is null;
update public.colleges set ror_id = '020vd6n84', aliases = 'National Institute of Technology Meghalaya | NIT Meghalaya | NITM', domains = 'nitm.ac.in' where id = 221 and ror_id is null;
update public.colleges set ror_id = '00aazk693', aliases = 'National Institute of Technology Manipur | NITMN', domains = '' where id = 222 and ror_id is null;
update public.colleges set ror_id = '04cbvzp68', aliases = 'National Institute of Technology Nagaland | NIT Nagaland | NITN', domains = '' where id = 224 and ror_id is null;
update public.colleges set ror_id = '04pam3b03', aliases = 'National Institute of Technology Sikkim | NIT Sikkim | NITSKM', domains = 'nitsikkim.ac.in' where id = 225 and ror_id is null;
update public.colleges set ror_id = '020cr8c43', aliases = 'National Institute of Technology Arunachal Pradesh | NIT Arunachal Pradesh | NITAP', domains = 'nitap.ac.in' where id = 226 and ror_id is null;
update public.colleges set ror_id = '0456pcg54', aliases = 'National Institute of Technology Andhra Pradesh | NIT Andhra Pradesh | NIT-AP', domains = 'nitandhra.ac.in' where id = 227 and ror_id is null;
update public.colleges set ror_id = '03rgjt374', aliases = 'Indian Institute of Information Technology Allahabad | Institut indien d''informatique d''allahabad | IIIT-A', domains = 'iiita.ac.in' where id = 228 and ror_id is null;
update public.colleges set ror_id = '05h9eqy10', aliases = 'International Institute of Information Technology Bangalore | IIIT-B', domains = 'iiitb.ac.in' where id = 230 and ror_id is null;
update public.colleges set ror_id = '008b3ap06', aliases = 'Atal Bihari Vajpayee Indian Institute of Information Technology and Management | Atal Bihari Vajpayee Indian Institute of Information Technology and Management, Indian Institute of Information Technology and Management, Gwalior | ABV-IIITM', domains = 'iiitm.ac.in' where id = 231 and ror_id is null;
update public.colleges set ror_id = '00gmd7q80', aliases = 'Indian Institute of Information Technology Design and Manufacturing Jabalpur | IIITD&M Jabalpur | IIITDM', domains = 'iiitdmj.ac.in' where id = 232 and ror_id is null;
update public.colleges set ror_id = '023c9pb11', aliases = 'Indian Institute of Information Technology, Design and Manufacturing, Kancheepuram | IIITD&M Kancheepuram | IIITDM', domains = 'iiitdm.ac.in' where id = 233 and ror_id is null;
update public.colleges set ror_id = '048m7sg95', aliases = 'Indian Institute of Information Technology Lucknow | IIIT Lucknow | IIITL', domains = 'iiitl.ac.in' where id = 234 and ror_id is null;
update public.colleges set ror_id = '00bb9ch64', aliases = 'Indian Institute of Information Technology Guwahati | IIIT G', domains = '' where id = 235 and ror_id is null;
update public.colleges set ror_id = '05dtb1875', aliases = 'Indian Institute of Information Technology Kota | IIIT Kota', domains = 'iiitkota.ac.in' where id = 236 and ror_id is null;
update public.colleges set ror_id = '01f8qyw75', aliases = 'Indian Institute of Information Technology, Pune | IIITP', domains = '' where id = 237 and ror_id is null;
update public.colleges set ror_id = '026873d40', aliases = 'Indian Institute of Information Technology Sri City | IIIT Sri City, Indian Institute of Information Technology Sri City, Chittoor | IIITS', domains = '' where id = 238 and ror_id is null;
update public.colleges set ror_id = '0163rt176', aliases = 'Indian Institute of Information Technology Vadodara | IIIT Vadodara', domains = 'iiitvadodara.ac.in' where id = 239 and ror_id is null;
update public.colleges set ror_id = '00qryer39', aliases = 'International Institute of Information Technology | IIIT Bhubaneswar | IIIT-BH', domains = '' where id = 240 and ror_id is null;
update public.colleges set ror_id = '04dese585', aliases = 'Indian Institute of Science Bangalore | IISc', domains = 'iisc.ac.in' where id = 242 and ror_id is null;
update public.colleges set ror_id = '02ytfzr55', aliases = 'Indian Institute of Engineering Science and Technology, Shibpur | IIEST Shibpur | IIEST', domains = 'iiests.ac.in' where id = 243 and ror_id is null;
update public.colleges set ror_id = '028vtqb15', aliases = 'Birla Institute of Technology, Mesra | BIT MESRA', domains = 'bitmesra.ac.in' where id = 244 and ror_id is null;
update public.colleges set ror_id = '046sh6j17', aliases = 'Birla Institute of Technology and Science, Pilani - Goa Campus | BITS Pilani, Goa Campus, Birla Institute of Technology and Science, Pilani - K. K. Birla Goa Campus | BPGC', domains = '' where id = 245 and ror_id is null;
update public.colleges set ror_id = '014ctt859', aliases = 'Birla Institute of Technology and Science - Hyderabad Campus | BITS Pilani, Hyderabad Campus | BPHC', domains = '' where id = 246 and ror_id is null;
update public.colleges set ror_id = '00bsj2955', aliases = 'Punjab Engineering College | East Panjab Engineering College, Maclagen Engineering College, PEC University of Technology | PEC', domains = 'pec.edu.in' where id = 247 and ror_id is null;
update public.colleges set ror_id = '00pnhhv55', aliases = 'Jamia Millia Islamia | National Islamic University | JMI', domains = 'jmi.ac.in' where id = 248 and ror_id is null;
update public.colleges set ror_id = '03kw9gc02', aliases = 'Aligarh Muslim University | Université musulmane d''aligarh | AMU', domains = 'amu.ac.in' where id = 249 and ror_id is null;
update public.colleges set ror_id = '04cdn2797', aliases = 'Banaras Hindu University | Université hindoue de bénarès | Benares Hindu University | Kashi Hindu Vishvavidyalay | BHU', domains = 'bhu.ac.in' where id = 250 and ror_id is null;
update public.colleges set ror_id = '04gzb2213', aliases = 'University of Delhi | Université de delhi | Delhi University', domains = 'du.ac.in' where id = 251 and ror_id is null;
update public.colleges set ror_id = '032hdk172', aliases = 'University of Mumbai | Université de mumbai | Mumbai University | MU', domains = 'mu.ac.in' where id = 252 and ror_id is null;
update public.colleges set ror_id = '044g6d731', aliases = 'Savitribai Phule Pune University | Université de pune | University of Poona, University of Pune', domains = 'unipune.ac.in' where id = 253 and ror_id is null;
update public.colleges set ror_id = '030sjb889', aliases = 'Osmania University | Université osmania | OU', domains = 'osmania.ac.in' where id = 254 and ror_id is null;
update public.colleges set ror_id = '049skhf47', aliases = 'Andhra University | Andhra Viswa Kala Parishath', domains = 'andhrauniversity.edu.in' where id = 255 and ror_id is null;
update public.colleges set ror_id = '03h56sg55', aliases = 'Dr. A.P.J. Abdul Kalam Technical University | Uttar Pradesh Technical University | AKTU', domains = 'aktu.ac.in' where id = 257 and ror_id is null;
update public.colleges set ror_id = '03b6ffh07', aliases = 'Sharda University', domains = 'sharda.ac.in' where id = 259 and ror_id is null;
update public.colleges set ror_id = '05x7qvh17', aliases = 'G.L. Bajaj Institute of Technology and Management Greater Noida | G L Bajaj Institute of Technology & Management Greater Noida, G. L. Bajaj Institute, GL Bajaj Institute of Technology and Management', domains = 'glbitm.ac.in' where id = 260 and ror_id is null;
update public.colleges set ror_id = '048rczr65', aliases = 'Noida Institute of Engineering and Technology | NIET', domains = 'niet.co.in' where id = 261 and ror_id is null;
update public.colleges set ror_id = '04hp0cf98', aliases = 'ABES Engineering College | ABES EC', domains = 'abes.ac.in' where id = 264 and ror_id is null;

-- Fills search for the rest.
update public.colleges set name = name where search = '';

-- Older apps load every college into one list. Show them the colleges
-- people play for (the 144 so far, and any college a player picks later),
-- not 34,000 rows. Search and the leaderboards read the table themselves.
drop policy if exists "colleges are public" on public.colleges;
drop policy if exists "colleges in play are public" on public.colleges;
create policy "colleges in play are public" on public.colleges
  for select to anon, authenticated
  using (source = 'apticks' or exists (select 1 from public.profiles p where p.college_id = colleges.id));

-- Up to 50 colleges whose name, city, aliases or web domain contain every
-- word typed, in any order, best first:
--   the exact name, or an exact short name ("MIT", "IIT Bombay");
--   the "University of X" / "X University" a single word usually means;
--   colleges people already play for, and ones in p_country (a hint: the
--   player's own country);
--   whole words over parts of words, then better-known colleges (weight:
--   a Wikipedia page, funding research), then shorter names.
create or replace function public.search_colleges(p_query text, p_limit int default 20, p_country text default null)
returns table (id int, name text, city text, country text, players int)
language sql stable security definer set search_path = '' as $$
  with q as (
    select public.college_text(p_query) as t, upper(nullif(btrim(coalesce(p_country, '')), '')) as cc
  ), words as (
    select w from q, unnest(string_to_array(q.t, ' ')) as w where w <> ''
  ), counts as (
    select p.college_id, count(*)::int as n from public.profiles p
    where p.college_id is not null and not p.is_bot and p.deleted_at is null
    group by p.college_id
  ), hits as (
    select c.id, c.name, c.city, c.country, coalesce(k.n, 0) as players, c.weight,
           (case when c.names[1] = q.t then 100 when q.t = any(c.names) then 40 else 0 end)
         + (case when c.names[1] in ('university of ' || q.t, q.t || ' university', q.t || ' college',
                                     q.t || ' institute of technology', 'universidad de ' || q.t,
                                     'universidade de ' || q.t, 'universite de ' || q.t) then 45 else 0 end)
         + (case when coalesce(k.n, 0) > 0 then 30 else 0 end)
         + (case when c.country = q.cc then 20 else 0 end)
         + (case when (' ' || c.search || ' ') like '% ' || q.t || ' %' then 10 else 0 end)
         + (case when c.search like q.t || '%' then 4 else 0 end) as score
    from public.colleges c
    cross join q
    left join counts k on k.college_id = c.id
    where length(q.t) >= 2
      -- the longest word narrows it down with the trigram index
      and c.search like '%' || (select w from words order by length(w) desc limit 1) || '%'
      and not exists (select 1 from words where c.search not like '%' || words.w || '%')
  )
  select h.id, h.name, h.city, h.country, h.players
  from hits h
  order by h.score desc, h.players desc, h.weight desc, length(h.name), h.name
  limit greatest(1, least(coalesce(p_limit, 20), 50))
$$;

-- A college that isn't on the list yet. Returns its id; an existing college
-- with the same name in that country (and city) is returned instead of a
-- copy. Up to 3 new colleges per player a day.
create or replace function public.add_college(p_name text, p_city text, p_country text)
returns int
language plpgsql security definer set search_path = '' as $$
declare
  v_name    text := btrim(regexp_replace(coalesce(p_name, ''), '\s+', ' ', 'g'));
  v_city    text := nullif(btrim(regexp_replace(coalesce(p_city, ''), '\s+', ' ', 'g')), '');
  v_country text := upper(btrim(coalesce(p_country, '')));
  v_id      int;
begin
  if auth.uid() is null then raise exception 'Sign in first.'; end if;
  if length(v_name) < 3 or length(v_name) > 120 then raise exception 'College names are 3 to 120 characters.'; end if;
  if v_city is not null and length(v_city) > 80 then raise exception 'That city name is too long.'; end if;
  if v_country !~ '^[A-Z]{2}$' then raise exception 'Choose a country.'; end if;

  select c.id into v_id from public.colleges c
  where lower(c.name) = lower(v_name) and coalesce(c.country, '') = v_country
    and (v_city is null or coalesce(c.city, '') = '' or lower(c.city) = lower(v_city))
  order by c.id limit 1;
  if v_id is not null then return v_id; end if;

  if (select count(*) from public.colleges c where c.added_by = auth.uid() and c.created_at > now() - interval '1 day') >= 3 then
    raise exception 'You can add up to 3 colleges a day.';
  end if;

  insert into public.colleges (name, city, country, source, added_by)
  values (v_name, v_city, v_country, 'user', auth.uid())
  returning id into v_id;
  return v_id;
end $$;

revoke execute on function public.college_text(text) from public, anon, authenticated;
revoke execute on function public.colleges_search() from public, anon, authenticated;
revoke execute on function public.search_colleges(text, int, text) from public;
grant execute on function public.search_colleges(text, int, text) to anon, authenticated;
revoke execute on function public.add_college(text, text, text) from public, anon;
grant execute on function public.add_college(text, text, text) to authenticated;
