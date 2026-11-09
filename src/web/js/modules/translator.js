/**
 * translator.js
 * Módulo de la Consola Interactiva del Traductor en Vivo de Vork (Pilar 01).
 * Selector interactivo con búsqueda inteligente por iniciales, nombre y sin tildes.
 */

(function (window, document) {
  "use strict";

  const POPULAR_LANGS = [
  {
    "value": "en",
    "label": "en (Inglés)",
    "search": "en inglés english"
  },
  {
    "value": "es",
    "label": "es (Español)",
    "search": "es español spanish"
  },
  {
    "value": "fr",
    "label": "fr (Francés)",
    "search": "fr francés french"
  },
  {
    "value": "de",
    "label": "de (Alemán)",
    "search": "de alemán german"
  },
  {
    "value": "it",
    "label": "it (Italiano)",
    "search": "it italiano italian"
  },
  {
    "value": "pt",
    "label": "pt (Portugués)",
    "search": "pt portugués portuguese (brazil)"
  },
  {
    "value": "ja",
    "label": "ja (Japonés)",
    "search": "ja japonés japanese"
  },
  {
    "value": "zh-CN",
    "label": "zh-CN (Chino (Simplificado))",
    "search": "zh-cn chino (simplificado) chinese (simplified)"
  },
  {
    "value": "ru",
    "label": "ru (Ruso)",
    "search": "ru ruso russian"
  },
  {
    "value": "ko",
    "label": "ko (Coreano)",
    "search": "ko coreano korean"
  },
  {
    "value": "ar",
    "label": "ar (Árabe)",
    "search": "ar árabe arabic"
  }
];
  const ALL_LANGS = [
  {
    "value": "en",
    "label": "en (Inglés)",
    "search": "en inglés english"
  },
  {
    "value": "es",
    "label": "es (Español)",
    "search": "es español spanish"
  },
  {
    "value": "fr",
    "label": "fr (Francés)",
    "search": "fr francés french"
  },
  {
    "value": "de",
    "label": "de (Alemán)",
    "search": "de alemán german"
  },
  {
    "value": "it",
    "label": "it (Italiano)",
    "search": "it italiano italian"
  },
  {
    "value": "pt",
    "label": "pt (Portugués)",
    "search": "pt portugués portuguese (brazil)"
  },
  {
    "value": "ja",
    "label": "ja (Japonés)",
    "search": "ja japonés japanese"
  },
  {
    "value": "zh-CN",
    "label": "zh-CN (Chino (Simplificado))",
    "search": "zh-cn chino (simplificado) chinese (simplified)"
  },
  {
    "value": "ru",
    "label": "ru (Ruso)",
    "search": "ru ruso russian"
  },
  {
    "value": "ko",
    "label": "ko (Coreano)",
    "search": "ko coreano korean"
  },
  {
    "value": "ar",
    "label": "ar (Árabe)",
    "search": "ar árabe arabic"
  },
  {
    "value": "aa",
    "label": "aa (Afar)",
    "search": "aa afar afar"
  },
  {
    "value": "ab",
    "label": "ab (Abkhaz)",
    "search": "ab abkhaz abkhaz"
  },
  {
    "value": "ace",
    "label": "ace (Acehnese)",
    "search": "ace acehnese acehnese"
  },
  {
    "value": "ach",
    "label": "ach (Acholi)",
    "search": "ach acholi acholi"
  },
  {
    "value": "af",
    "label": "af (Afrikáans)",
    "search": "af afrikáans afrikaans"
  },
  {
    "value": "ak",
    "label": "ak (Twi)",
    "search": "ak twi twi"
  },
  {
    "value": "alz",
    "label": "alz (Alur)",
    "search": "alz alur alur"
  },
  {
    "value": "am",
    "label": "am (Amhárico)",
    "search": "am amhárico amharic"
  },
  {
    "value": "as",
    "label": "as (Assamese)",
    "search": "as assamese assamese"
  },
  {
    "value": "av",
    "label": "av (Avar)",
    "search": "av avar avar"
  },
  {
    "value": "awa",
    "label": "awa (Awadhi)",
    "search": "awa awadhi awadhi"
  },
  {
    "value": "ay",
    "label": "ay (Aimara)",
    "search": "ay aimara aymara"
  },
  {
    "value": "az",
    "label": "az (Azerbaiyano)",
    "search": "az azerbaiyano azerbaijani"
  },
  {
    "value": "ba",
    "label": "ba (Bashkir)",
    "search": "ba bashkir bashkir"
  },
  {
    "value": "bal",
    "label": "bal (Baluchi)",
    "search": "bal baluchi baluchi"
  },
  {
    "value": "ban",
    "label": "ban (Balinese)",
    "search": "ban balinese balinese"
  },
  {
    "value": "bbc",
    "label": "bbc (Batak Toba)",
    "search": "bbc batak toba batak toba"
  },
  {
    "value": "bci",
    "label": "bci (Baoulé)",
    "search": "bci baoulé baoulé"
  },
  {
    "value": "be",
    "label": "be (Bielorruso)",
    "search": "be bielorruso belarusian"
  },
  {
    "value": "bem",
    "label": "bem (Bemba)",
    "search": "bem bemba bemba"
  },
  {
    "value": "ber",
    "label": "ber (Tamazight (Tifinagh))",
    "search": "ber tamazight (tifinagh) tamazight (tifinagh)"
  },
  {
    "value": "ber-Latn",
    "label": "ber-Latn (Tamazight)",
    "search": "ber-latn tamazight tamazight"
  },
  {
    "value": "bew",
    "label": "bew (Betawi)",
    "search": "bew betawi betawi"
  },
  {
    "value": "bg",
    "label": "bg (Búlgaro)",
    "search": "bg búlgaro bulgarian"
  },
  {
    "value": "bho",
    "label": "bho (Bhojpuri)",
    "search": "bho bhojpuri bhojpuri"
  },
  {
    "value": "bik",
    "label": "bik (Bikol)",
    "search": "bik bikol bikol"
  },
  {
    "value": "bm",
    "label": "bm (Bambara)",
    "search": "bm bambara bambara"
  },
  {
    "value": "bm-Nkoo",
    "label": "bm-Nkoo (NKo)",
    "search": "bm-nkoo nko nko"
  },
  {
    "value": "bn",
    "label": "bn (Bengalí)",
    "search": "bn bengalí bengali"
  },
  {
    "value": "bo",
    "label": "bo (Tibetan)",
    "search": "bo tibetan tibetan"
  },
  {
    "value": "br",
    "label": "br (Breton)",
    "search": "br breton breton"
  },
  {
    "value": "bs",
    "label": "bs (Bosnio)",
    "search": "bs bosnio bosnian"
  },
  {
    "value": "bts",
    "label": "bts (Batak Simalungun)",
    "search": "bts batak simalungun batak simalungun"
  },
  {
    "value": "btx",
    "label": "btx (Batak Karo)",
    "search": "btx batak karo batak karo"
  },
  {
    "value": "bua",
    "label": "bua (Buryat)",
    "search": "bua buryat buryat"
  },
  {
    "value": "ca",
    "label": "ca (Catalán)",
    "search": "ca catalán catalan"
  },
  {
    "value": "ce",
    "label": "ce (Chechen)",
    "search": "ce chechen chechen"
  },
  {
    "value": "ceb",
    "label": "ceb (Cebuano)",
    "search": "ceb cebuano cebuano"
  },
  {
    "value": "cgg",
    "label": "cgg (Kiga)",
    "search": "cgg kiga kiga"
  },
  {
    "value": "ch",
    "label": "ch (Chamorro)",
    "search": "ch chamorro chamorro"
  },
  {
    "value": "chk",
    "label": "chk (Chuukese)",
    "search": "chk chuukese chuukese"
  },
  {
    "value": "chm",
    "label": "chm (Meadow Mari)",
    "search": "chm meadow mari meadow mari"
  },
  {
    "value": "ckb",
    "label": "ckb (Kurdish (Sorani))",
    "search": "ckb kurdish (sorani) kurdish (sorani)"
  },
  {
    "value": "cnh",
    "label": "cnh (Hakha Chin)",
    "search": "cnh hakha chin hakha chin"
  },
  {
    "value": "co",
    "label": "co (Corso)",
    "search": "co corso corsican"
  },
  {
    "value": "crh",
    "label": "crh (Crimean Tatar (Cyrillic))",
    "search": "crh crimean tatar (cyrillic) crimean tatar (cyrillic)"
  },
  {
    "value": "crh-Latn",
    "label": "crh-Latn (Crimean Tatar (Latin))",
    "search": "crh-latn crimean tatar (latin) crimean tatar (latin)"
  },
  {
    "value": "crs",
    "label": "crs (Seychellois Creole)",
    "search": "crs seychellois creole seychellois creole"
  },
  {
    "value": "cs",
    "label": "cs (Checo)",
    "search": "cs checo czech"
  },
  {
    "value": "cv",
    "label": "cv (Chuvash)",
    "search": "cv chuvash chuvash"
  },
  {
    "value": "cy",
    "label": "cy (Galés)",
    "search": "cy galés welsh"
  },
  {
    "value": "da",
    "label": "da (Danés)",
    "search": "da danés danish"
  },
  {
    "value": "din",
    "label": "din (Dinka)",
    "search": "din dinka dinka"
  },
  {
    "value": "doi",
    "label": "doi (Dogri)",
    "search": "doi dogri dogri"
  },
  {
    "value": "dov",
    "label": "dov (Dombe)",
    "search": "dov dombe dombe"
  },
  {
    "value": "dv",
    "label": "dv (Dhivehi)",
    "search": "dv dhivehi dhivehi"
  },
  {
    "value": "dyu",
    "label": "dyu (Dyula)",
    "search": "dyu dyula dyula"
  },
  {
    "value": "dz",
    "label": "dz (Dzongkha)",
    "search": "dz dzongkha dzongkha"
  },
  {
    "value": "ee",
    "label": "ee (Ewe)",
    "search": "ee ewe ewe"
  },
  {
    "value": "el",
    "label": "el (Griego)",
    "search": "el griego greek"
  },
  {
    "value": "eo",
    "label": "eo (Esperanto)",
    "search": "eo esperanto esperanto"
  },
  {
    "value": "et",
    "label": "et (Estonio)",
    "search": "et estonio estonian"
  },
  {
    "value": "eu",
    "label": "eu (Vasco / Euskera)",
    "search": "eu vasco / euskera basque"
  },
  {
    "value": "fa",
    "label": "fa (Persa)",
    "search": "fa persa persian"
  },
  {
    "value": "fa-AF",
    "label": "fa-AF (Dari)",
    "search": "fa-af dari dari"
  },
  {
    "value": "ff",
    "label": "ff (Fulani)",
    "search": "ff fulani fulani"
  },
  {
    "value": "fi",
    "label": "fi (Finlandés)",
    "search": "fi finlandés finnish"
  },
  {
    "value": "fj",
    "label": "fj (Fijian)",
    "search": "fj fijian fijian"
  },
  {
    "value": "fo",
    "label": "fo (Faroese)",
    "search": "fo faroese faroese"
  },
  {
    "value": "fon",
    "label": "fon (Fon)",
    "search": "fon fon fon"
  },
  {
    "value": "fr-CA",
    "label": "fr-CA (French (Canada))",
    "search": "fr-ca french (canada) french (canada)"
  },
  {
    "value": "fur",
    "label": "fur (Friulian)",
    "search": "fur friulian friulian"
  },
  {
    "value": "fy",
    "label": "fy (Frisón)",
    "search": "fy frisón frisian"
  },
  {
    "value": "ga",
    "label": "ga (Irlandés)",
    "search": "ga irlandés irish"
  },
  {
    "value": "gaa",
    "label": "gaa (Ga)",
    "search": "gaa ga ga"
  },
  {
    "value": "gd",
    "label": "gd (Gaélico escocés)",
    "search": "gd gaélico escocés scots gaelic"
  },
  {
    "value": "gl",
    "label": "gl (Gallego)",
    "search": "gl gallego galician"
  },
  {
    "value": "gn",
    "label": "gn (Guaraní)",
    "search": "gn guaraní guarani"
  },
  {
    "value": "gom",
    "label": "gom (Konkani)",
    "search": "gom konkani konkani"
  },
  {
    "value": "gu",
    "label": "gu (Guyaratí)",
    "search": "gu guyaratí gujarati"
  },
  {
    "value": "gv",
    "label": "gv (Manx)",
    "search": "gv manx manx"
  },
  {
    "value": "ha",
    "label": "ha (Hausa)",
    "search": "ha hausa hausa"
  },
  {
    "value": "haw",
    "label": "haw (Hawaiano)",
    "search": "haw hawaiano hawaiian"
  },
  {
    "value": "he",
    "label": "he (Hebreo)",
    "search": "he hebreo hebrew"
  },
  {
    "value": "hi",
    "label": "hi (Hindi)",
    "search": "hi hindi hindi"
  },
  {
    "value": "hil",
    "label": "hil (Hiligaynon)",
    "search": "hil hiligaynon hiligaynon"
  },
  {
    "value": "hmn",
    "label": "hmn (Hmong)",
    "search": "hmn hmong hmong"
  },
  {
    "value": "hr",
    "label": "hr (Croata)",
    "search": "hr croata croatian"
  },
  {
    "value": "hrx",
    "label": "hrx (Hunsrik)",
    "search": "hrx hunsrik hunsrik"
  },
  {
    "value": "ht",
    "label": "ht (Criollo haitiano)",
    "search": "ht criollo haitiano haitian creole"
  },
  {
    "value": "hu",
    "label": "hu (Húngaro)",
    "search": "hu húngaro hungarian"
  },
  {
    "value": "hy",
    "label": "hy (Armenio)",
    "search": "hy armenio armenian"
  },
  {
    "value": "iba",
    "label": "iba (Iban)",
    "search": "iba iban iban"
  },
  {
    "value": "id",
    "label": "id (Indonesio)",
    "search": "id indonesio indonesian"
  },
  {
    "value": "ig",
    "label": "ig (Igbo)",
    "search": "ig igbo igbo"
  },
  {
    "value": "ilo",
    "label": "ilo (Ilocano)",
    "search": "ilo ilocano ilocano"
  },
  {
    "value": "is",
    "label": "is (Islandés)",
    "search": "is islandés icelandic"
  },
  {
    "value": "iu",
    "label": "iu (Inuktut (Syllabics))",
    "search": "iu inuktut (syllabics) inuktut (syllabics)"
  },
  {
    "value": "iu-Latn",
    "label": "iu-Latn (Inuktut (Latin))",
    "search": "iu-latn inuktut (latin) inuktut (latin)"
  },
  {
    "value": "iw",
    "label": "iw (Hebrew)",
    "search": "iw hebrew hebrew"
  },
  {
    "value": "jam",
    "label": "jam (Jamaican Patois)",
    "search": "jam jamaican patois jamaican patois"
  },
  {
    "value": "jw",
    "label": "jw (Javanese)",
    "search": "jw javanese javanese"
  },
  {
    "value": "ka",
    "label": "ka (Georgiano)",
    "search": "ka georgiano georgian"
  },
  {
    "value": "kac",
    "label": "kac (Jingpo)",
    "search": "kac jingpo jingpo"
  },
  {
    "value": "kek",
    "label": "kek (Qʼeqchiʼ)",
    "search": "kek qʼeqchiʼ qʼeqchiʼ"
  },
  {
    "value": "kg",
    "label": "kg (Kikongo)",
    "search": "kg kikongo kikongo"
  },
  {
    "value": "kha",
    "label": "kha (Khasi)",
    "search": "kha khasi khasi"
  },
  {
    "value": "kk",
    "label": "kk (Kazajo)",
    "search": "kk kazajo kazakh"
  },
  {
    "value": "kl",
    "label": "kl (Kalaallisut)",
    "search": "kl kalaallisut kalaallisut"
  },
  {
    "value": "km",
    "label": "km (Jemer)",
    "search": "km jemer khmer"
  },
  {
    "value": "kn",
    "label": "kn (Canarés / Kannada)",
    "search": "kn canarés / kannada kannada"
  },
  {
    "value": "kr",
    "label": "kr (Kanuri)",
    "search": "kr kanuri kanuri"
  },
  {
    "value": "kri",
    "label": "kri (Krio)",
    "search": "kri krio krio"
  },
  {
    "value": "ktu",
    "label": "ktu (Kituba)",
    "search": "ktu kituba kituba"
  },
  {
    "value": "ku",
    "label": "ku (Kurdo)",
    "search": "ku kurdo kurdish (kurmanji)"
  },
  {
    "value": "kv",
    "label": "kv (Komi)",
    "search": "kv komi komi"
  },
  {
    "value": "ky",
    "label": "ky (Kirguís)",
    "search": "ky kirguís kyrgyz"
  },
  {
    "value": "la",
    "label": "la (Latín)",
    "search": "la latín latin"
  },
  {
    "value": "lb",
    "label": "lb (Luxemburgués)",
    "search": "lb luxemburgués luxembourgish"
  },
  {
    "value": "lg",
    "label": "lg (Luganda)",
    "search": "lg luganda luganda"
  },
  {
    "value": "li",
    "label": "li (Limburgish)",
    "search": "li limburgish limburgish"
  },
  {
    "value": "lij",
    "label": "lij (Ligurian)",
    "search": "lij ligurian ligurian"
  },
  {
    "value": "lmo",
    "label": "lmo (Lombard)",
    "search": "lmo lombard lombard"
  },
  {
    "value": "ln",
    "label": "ln (Lingala)",
    "search": "ln lingala lingala"
  },
  {
    "value": "lo",
    "label": "lo (Laosiano)",
    "search": "lo laosiano lao"
  },
  {
    "value": "lt",
    "label": "lt (Lituano)",
    "search": "lt lituano lithuanian"
  },
  {
    "value": "ltg",
    "label": "ltg (Latgalian)",
    "search": "ltg latgalian latgalian"
  },
  {
    "value": "lua",
    "label": "lua (Tshiluba)",
    "search": "lua tshiluba tshiluba"
  },
  {
    "value": "luo",
    "label": "luo (Luo)",
    "search": "luo luo luo"
  },
  {
    "value": "lus",
    "label": "lus (Mizo)",
    "search": "lus mizo mizo"
  },
  {
    "value": "lv",
    "label": "lv (Letón)",
    "search": "lv letón latvian"
  },
  {
    "value": "mad",
    "label": "mad (Madurese)",
    "search": "mad madurese madurese"
  },
  {
    "value": "mai",
    "label": "mai (Maithili)",
    "search": "mai maithili maithili"
  },
  {
    "value": "mak",
    "label": "mak (Makassar)",
    "search": "mak makassar makassar"
  },
  {
    "value": "mam",
    "label": "mam (Mam)",
    "search": "mam mam mam"
  },
  {
    "value": "mfe",
    "label": "mfe (Mauritian Creole)",
    "search": "mfe mauritian creole mauritian creole"
  },
  {
    "value": "mg",
    "label": "mg (Malgache)",
    "search": "mg malgache malagasy"
  },
  {
    "value": "mh",
    "label": "mh (Marshallese)",
    "search": "mh marshallese marshallese"
  },
  {
    "value": "mi",
    "label": "mi (Maorí)",
    "search": "mi maorí maori"
  },
  {
    "value": "min",
    "label": "min (Minang)",
    "search": "min minang minang"
  },
  {
    "value": "mk",
    "label": "mk (Macedonio)",
    "search": "mk macedonio macedonian"
  },
  {
    "value": "ml",
    "label": "ml (Malayalam)",
    "search": "ml malayalam malayalam"
  },
  {
    "value": "mn",
    "label": "mn (Mongol)",
    "search": "mn mongol mongolian"
  },
  {
    "value": "mni-Mtei",
    "label": "mni-Mtei (Meiteilon (Manipuri))",
    "search": "mni-mtei meiteilon (manipuri) meiteilon (manipuri)"
  },
  {
    "value": "mr",
    "label": "mr (Maratí)",
    "search": "mr maratí marathi"
  },
  {
    "value": "ms",
    "label": "ms (Malayo)",
    "search": "ms malayo malay"
  },
  {
    "value": "ms-Arab",
    "label": "ms-Arab (Malay (Jawi))",
    "search": "ms-arab malay (jawi) malay (jawi)"
  },
  {
    "value": "mt",
    "label": "mt (Maltés)",
    "search": "mt maltés maltese"
  },
  {
    "value": "mwr",
    "label": "mwr (Marwadi)",
    "search": "mwr marwadi marwadi"
  },
  {
    "value": "my",
    "label": "my (Birmano)",
    "search": "my birmano myanmar (burmese)"
  },
  {
    "value": "ndc-ZW",
    "label": "ndc-ZW (Ndau)",
    "search": "ndc-zw ndau ndau"
  },
  {
    "value": "ne",
    "label": "ne (Nepalí)",
    "search": "ne nepalí nepali"
  },
  {
    "value": "new",
    "label": "new (Nepalbhasa (Newari))",
    "search": "new nepalbhasa (newari) nepalbhasa (newari)"
  },
  {
    "value": "nhe",
    "label": "nhe (Nahuatl (Eastern Huasteca))",
    "search": "nhe nahuatl (eastern huasteca) nahuatl (eastern huasteca)"
  },
  {
    "value": "nl",
    "label": "nl (Holandés / Neerlandés)",
    "search": "nl holandés / neerlandés dutch"
  },
  {
    "value": "no",
    "label": "no (Noruego)",
    "search": "no noruego norwegian"
  },
  {
    "value": "nr",
    "label": "nr (Ndebele (South))",
    "search": "nr ndebele (south) ndebele (south)"
  },
  {
    "value": "nso",
    "label": "nso (Sepedi)",
    "search": "nso sepedi sepedi"
  },
  {
    "value": "nus",
    "label": "nus (Nuer)",
    "search": "nus nuer nuer"
  },
  {
    "value": "ny",
    "label": "ny (Chichewa)",
    "search": "ny chichewa chichewa"
  },
  {
    "value": "oc",
    "label": "oc (Occitan)",
    "search": "oc occitan occitan"
  },
  {
    "value": "om",
    "label": "om (Oromo)",
    "search": "om oromo oromo"
  },
  {
    "value": "or",
    "label": "or (Odia)",
    "search": "or odia odia (oriya)"
  },
  {
    "value": "os",
    "label": "os (Ossetian)",
    "search": "os ossetian ossetian"
  },
  {
    "value": "pa",
    "label": "pa (Panyabí)",
    "search": "pa panyabí punjabi (gurmukhi)"
  },
  {
    "value": "pa-Arab",
    "label": "pa-Arab (Punjabi (Shahmukhi))",
    "search": "pa-arab punjabi (shahmukhi) punjabi (shahmukhi)"
  },
  {
    "value": "pag",
    "label": "pag (Pangasinan)",
    "search": "pag pangasinan pangasinan"
  },
  {
    "value": "pam",
    "label": "pam (Kapampangan)",
    "search": "pam kapampangan kapampangan"
  },
  {
    "value": "pap",
    "label": "pap (Papiamento)",
    "search": "pap papiamento papiamento"
  },
  {
    "value": "pl",
    "label": "pl (Polaco)",
    "search": "pl polaco polish"
  },
  {
    "value": "ps",
    "label": "ps (Pastún)",
    "search": "ps pastún pashto"
  },
  {
    "value": "pt-PT",
    "label": "pt-PT (Portuguese (Portugal))",
    "search": "pt-pt portuguese (portugal) portuguese (portugal)"
  },
  {
    "value": "qu",
    "label": "qu (Quechua)",
    "search": "qu quechua quechua"
  },
  {
    "value": "rn",
    "label": "rn (Rundi)",
    "search": "rn rundi rundi"
  },
  {
    "value": "ro",
    "label": "ro (Rumano)",
    "search": "ro rumano romanian"
  },
  {
    "value": "rom",
    "label": "rom (Romani)",
    "search": "rom romani romani"
  },
  {
    "value": "rw",
    "label": "rw (Kinyarwanda)",
    "search": "rw kinyarwanda kinyarwanda"
  },
  {
    "value": "sa",
    "label": "sa (Sanskrit)",
    "search": "sa sanskrit sanskrit"
  },
  {
    "value": "sah",
    "label": "sah (Yakut)",
    "search": "sah yakut yakut"
  },
  {
    "value": "sat",
    "label": "sat (Santali (Ol Chiki))",
    "search": "sat santali (ol chiki) santali (ol chiki)"
  },
  {
    "value": "sat-Latn",
    "label": "sat-Latn (Santali (Latin))",
    "search": "sat-latn santali (latin) santali (latin)"
  },
  {
    "value": "scn",
    "label": "scn (Sicilian)",
    "search": "scn sicilian sicilian"
  },
  {
    "value": "sd",
    "label": "sd (Sindhi)",
    "search": "sd sindhi sindhi"
  },
  {
    "value": "se",
    "label": "se (Sami (North))",
    "search": "se sami (north) sami (north)"
  },
  {
    "value": "sg",
    "label": "sg (Sango)",
    "search": "sg sango sango"
  },
  {
    "value": "shn",
    "label": "shn (Shan)",
    "search": "shn shan shan"
  },
  {
    "value": "si",
    "label": "si (Cingalés)",
    "search": "si cingalés sinhala"
  },
  {
    "value": "sk",
    "label": "sk (Eslovaco)",
    "search": "sk eslovaco slovak"
  },
  {
    "value": "sl",
    "label": "sl (Esloveno)",
    "search": "sl esloveno slovenian"
  },
  {
    "value": "sm",
    "label": "sm (Samoano)",
    "search": "sm samoano samoan"
  },
  {
    "value": "sn",
    "label": "sn (Shona)",
    "search": "sn shona shona"
  },
  {
    "value": "so",
    "label": "so (Somalí)",
    "search": "so somalí somali"
  },
  {
    "value": "sq",
    "label": "sq (Albanés)",
    "search": "sq albanés albanian"
  },
  {
    "value": "sr",
    "label": "sr (Serbio)",
    "search": "sr serbio serbian"
  },
  {
    "value": "ss",
    "label": "ss (Swati)",
    "search": "ss swati swati"
  },
  {
    "value": "st",
    "label": "st (Sesoto)",
    "search": "st sesoto sesotho"
  },
  {
    "value": "su",
    "label": "su (Sundanés)",
    "search": "su sundanés sundanese"
  },
  {
    "value": "sus",
    "label": "sus (Susu)",
    "search": "sus susu susu"
  },
  {
    "value": "sv",
    "label": "sv (Sueco)",
    "search": "sv sueco swedish"
  },
  {
    "value": "sw",
    "label": "sw (Suajili)",
    "search": "sw suajili swahili"
  },
  {
    "value": "szl",
    "label": "szl (Silesian)",
    "search": "szl silesian silesian"
  },
  {
    "value": "ta",
    "label": "ta (Tamil)",
    "search": "ta tamil tamil"
  },
  {
    "value": "tcy",
    "label": "tcy (Tulu)",
    "search": "tcy tulu tulu"
  },
  {
    "value": "te",
    "label": "te (Telugu)",
    "search": "te telugu telugu"
  },
  {
    "value": "tet",
    "label": "tet (Tetum)",
    "search": "tet tetum tetum"
  },
  {
    "value": "tg",
    "label": "tg (Tayiko)",
    "search": "tg tayiko tajik"
  },
  {
    "value": "th",
    "label": "th (Tailandés)",
    "search": "th tailandés thai"
  },
  {
    "value": "ti",
    "label": "ti (Tigrinya)",
    "search": "ti tigrinya tigrinya"
  },
  {
    "value": "tiv",
    "label": "tiv (Tiv)",
    "search": "tiv tiv tiv"
  },
  {
    "value": "tk",
    "label": "tk (Turcomano)",
    "search": "tk turcomano turkmen"
  },
  {
    "value": "tl",
    "label": "tl (Tagalo / Filipino)",
    "search": "tl tagalo / filipino filipino"
  },
  {
    "value": "tn",
    "label": "tn (Tswana)",
    "search": "tn tswana tswana"
  },
  {
    "value": "to",
    "label": "to (Tongan)",
    "search": "to tongan tongan"
  },
  {
    "value": "tpi",
    "label": "tpi (Tok Pisin)",
    "search": "tpi tok pisin tok pisin"
  },
  {
    "value": "tr",
    "label": "tr (Turco)",
    "search": "tr turco turkish"
  },
  {
    "value": "trp",
    "label": "trp (Kokborok)",
    "search": "trp kokborok kokborok"
  },
  {
    "value": "ts",
    "label": "ts (Tsonga)",
    "search": "ts tsonga tsonga"
  },
  {
    "value": "tt",
    "label": "tt (Tártaro)",
    "search": "tt tártaro tatar"
  },
  {
    "value": "tum",
    "label": "tum (Tumbuka)",
    "search": "tum tumbuka tumbuka"
  },
  {
    "value": "ty",
    "label": "ty (Tahitian)",
    "search": "ty tahitian tahitian"
  },
  {
    "value": "tyv",
    "label": "tyv (Tuvan)",
    "search": "tyv tuvan tuvan"
  },
  {
    "value": "udm",
    "label": "udm (Udmurt)",
    "search": "udm udmurt udmurt"
  },
  {
    "value": "ug",
    "label": "ug (Uigur)",
    "search": "ug uigur uyghur"
  },
  {
    "value": "uk",
    "label": "uk (Ucraniano)",
    "search": "uk ucraniano ukrainian"
  },
  {
    "value": "ur",
    "label": "ur (Urdu)",
    "search": "ur urdu urdu"
  },
  {
    "value": "uz",
    "label": "uz (Uzbeko)",
    "search": "uz uzbeko uzbek"
  },
  {
    "value": "ve",
    "label": "ve (Venda)",
    "search": "ve venda venda"
  },
  {
    "value": "vec",
    "label": "vec (Venetian)",
    "search": "vec venetian venetian"
  },
  {
    "value": "vi",
    "label": "vi (Vietnamita)",
    "search": "vi vietnamita vietnamese"
  },
  {
    "value": "war",
    "label": "war (Waray)",
    "search": "war waray waray"
  },
  {
    "value": "wo",
    "label": "wo (Wolof)",
    "search": "wo wolof wolof"
  },
  {
    "value": "xh",
    "label": "xh (Xhosa)",
    "search": "xh xhosa xhosa"
  },
  {
    "value": "yi",
    "label": "yi (Yidis)",
    "search": "yi yidis yiddish"
  },
  {
    "value": "yo",
    "label": "yo (Yoruba)",
    "search": "yo yoruba yoruba"
  },
  {
    "value": "yua",
    "label": "yua (Yucatec Maya)",
    "search": "yua yucatec maya yucatec maya"
  },
  {
    "value": "yue",
    "label": "yue (Cantonese)",
    "search": "yue cantonese cantonese"
  },
  {
    "value": "zap",
    "label": "zap (Zapotec)",
    "search": "zap zapotec zapotec"
  },
  {
    "value": "zh-TW",
    "label": "zh-TW (Chino (Tradicional))",
    "search": "zh-tw chino (tradicional) chinese (traditional)"
  },
  {
    "value": "zu",
    "label": "zu (Zulú)",
    "search": "zu zulú zulu"
  }
];

  const translatorClientCache = new Map();

  function normalizeText(s) {
    return (s || "")
      .normalize("NFD")
      .replace(/[\u0300-\u036f]/g, "")
      .toLowerCase()
      .trim();
  }

  function initTranslatorModule() {
    // 1. Inicialización de Vork SDK para el sitio
    const apiEndpoint = "/api/translate";
    if (window.Vork && !window.translator) {
      window.translator = new window.Vork({
        apiEndpoint: apiEndpoint,
        useCookies: true
      });
    }

    // 2. Elementos DOM
    const inputSourceLang = document.getElementById("translator-source-lang");
    const inputTargetLang = document.getElementById("translator-target-lang");
    const sourceTrigger = document.getElementById("source-lang-trigger");
    const targetTrigger = document.getElementById("target-lang-trigger");
    const sourceCurrent = document.getElementById("source-lang-current");
    const targetCurrent = document.getElementById("target-lang-current");
    const sourceSearchInput = document.getElementById("source-lang-search");
    const targetSearchInput = document.getElementById("target-lang-search");
    const sourceContainer = document.getElementById("source-lang-container");
    const targetContainer = document.getElementById("target-lang-container");
    const sourceMenu = document.getElementById("source-lang-menu");
    const targetMenu = document.getElementById("target-lang-menu");
    const sourceList = document.getElementById("source-lang-list");
    const targetList = document.getElementById("target-lang-list");

    const btnSwapLang = document.getElementById("btn-swap-lang");
    const inputText = document.getElementById("translator-input-text");
    const btnClearInput = document.getElementById("btn-clear-input");
    const charCount = document.getElementById("translator-char-count");
    const wordCount = document.getElementById("translator-word-count");
    const btnRun = document.getElementById("btn-run-translator");
    const outputText = document.getElementById("translator-output-text");
    const outputJson = document.getElementById("translator-output-json");
    const stats = document.getElementById("translator-stats");
    const btnCopyResult = document.getElementById("btn-copy-result");
    const btnDownloadResult = document.getElementById("btn-download-result");
    const btnCopyInstall = document.getElementById("btn-copy-install");

    // Iconos SVG
    const ICON_TRANSLATE = '<svg id="btn-run-icon" class="btn-action-icon" viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M5 8l6 6"/><path d="M4 14l6-6 2-3"/><path d="M2 5h12"/><path d="M7 2h1"/><path d="m22 22-5-10-5 10"/><path d="M14 18h6"/></svg>';
    const ICON_LOADING = '<svg class="spin-icon" viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10" stroke-opacity="0.25" stroke="currentColor"/><path d="M12 2a10 10 0 0 1 10 10" stroke="currentColor"/></svg>';
    const ICON_CHECK = '<svg class="check-pop-icon" viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="#10b981" stroke-width="2.8" stroke-linecap="round" stroke-linejoin="round"><path d="M20 6L9 17l-5-5"/></svg>';

    const ICON_COPY_DEFAULT = '<svg class="icon" viewBox="0 0 24 24" width="17" height="17" stroke="currentColor" fill="none" stroke-width="2"><rect width="14" height="14" x="8" y="8" rx="2" ry="2"/><path d="M4 16c-1.1 0-2-.9-2-2V4c0-1.1.9-2 2-2h10c1.1 0 2 .9 2 2"/></svg>';
    const ICON_COPY_SUCCESS = '<svg class="icon" viewBox="0 0 24 24" width="17" height="17" stroke="#10b981" fill="none" stroke-width="2.5"><path d="M20 6L9 17l-5-5"/></svg>';

    // Mapa para resolución rápida de etiquetas
    const langLabelMap = new Map();
    langLabelMap.set("auto", "Detectar idioma automáticamente (auto)");
    ALL_LANGS.forEach(l => {
      langLabelMap.set(l.value.toLowerCase(), l.label);
      if (l.search) langLabelMap.set(normalizeText(l.search), l.label);
    });

    // Función de filtrado con soporte insensible a tildes e iniciales
    function getFilteredLangs(filterText, isSource) {
      const q = normalizeText(filterText);
      let list = [];
      if (isSource) {
        list.push({ value: "auto", label: "Detectar idioma automáticamente (auto)", code: "auto", search: "auto detectar automatico" });
      }
      list = list.concat(ALL_LANGS);

      if (!q) return list;

      return list.filter(item => {
        const codeNorm = normalizeText(item.value || item.code);
        const labelNorm = normalizeText(item.label);
        const searchNorm = normalizeText(item.search || "");

        // Coincidencia por código directo (ej: 'en', 'es', 'ja')
        if (codeNorm === q || codeNorm.startsWith(q)) return true;
        // Coincidencia por etiqueta (ej: 'ingles', 'japon')
        if (labelNorm.includes(q)) return true;
        // Coincidencia por alias de búsqueda
        if (searchNorm && searchNorm.includes(q)) return true;
        return false;
      }).sort((a, b) => {
        const aCode = normalizeText(a.value || a.code);
        const bCode = normalizeText(b.value || b.code);
        const aLabel = normalizeText(a.label);
        const bLabel = normalizeText(b.label);

        // Coincidencia exacta de código (ej: 'en' === 'en')
        if (aCode === q && bCode !== q) return -1;
        if (bCode === q && aCode !== q) return 1;

        // Comienza con el código (ej: 'es' -> 'es')
        if (aCode.startsWith(q) && !bCode.startsWith(q)) return -1;
        if (bCode.startsWith(q) && !aCode.startsWith(q)) return 1;

        // Comienza con el nombre del idioma (ej: 'ing' -> 'ingles')
        const aName = aLabel.replace(/^[a-z\-]+\s*\(/, "");
        const bName = bLabel.replace(/^[a-z\-]+\s*\(/, "");
        if (aName.startsWith(q) && !bName.startsWith(q)) return -1;
        if (bName.startsWith(q) && !aName.startsWith(q)) return 1;

        return 0;
      });
    }

    // Renderizar menú desplegable
    function renderComboMenu(menuEl, filterText, isSource, onSelect) {
      if (!menuEl) return;
      menuEl.innerHTML = "";
      const matches = getFilteredLangs(filterText, isSource);

      if (matches.length === 0) {
        const empty = document.createElement("div");
        empty.className = "combo-empty";
        empty.textContent = "No se encontraron resultados";
        menuEl.appendChild(empty);
        return;
      }

      matches.forEach(item => {
        const row = document.createElement("div");
        row.className = "combo-item";
        row.setAttribute("data-value", item.value);
        row.innerHTML = '<span class="combo-item-label">' + item.label + '</span><span class="combo-item-code">' + (item.value || item.code) + '</span>';
        
        row.addEventListener("pointerdown", (e) => {
          e.preventDefault();
          e.stopPropagation();
          onSelect(item);
        });

        menuEl.appendChild(row);
      });
    }

    // Configurar Selector Origen (Botón Trigger + Búsqueda dentro del Menú)
    if (sourceTrigger && sourceContainer && sourceSearchInput && sourceList && !sourceTrigger._boundCombo) {
      sourceTrigger._boundCombo = true;

      const selectSourceItem = (item) => {
        if (sourceCurrent) sourceCurrent.textContent = item.label;
        if (inputSourceLang) {
          inputSourceLang.value = item.value;
          inputSourceLang.dispatchEvent(new Event("change", { bubbles: true }));
        }
        sourceContainer.classList.remove("is-open");
        sourceTrigger.setAttribute("aria-expanded", "false");
        sourceTrigger.focus();
      };

      const toggleSourceMenu = () => {
        const willOpen = !sourceContainer.classList.contains("is-open");
        if (targetContainer) {
          targetContainer.classList.remove("is-open");
          if (targetTrigger) targetTrigger.setAttribute("aria-expanded", "false");
        }
        if (willOpen) {
          sourceContainer.classList.add("is-open");
          sourceTrigger.setAttribute("aria-expanded", "true");
          sourceSearchInput.value = "";
          renderComboMenu(sourceList, "", true, selectSourceItem);
          setTimeout(() => {
            sourceSearchInput.focus();
          }, 40);
        } else {
          sourceContainer.classList.remove("is-open");
          sourceTrigger.setAttribute("aria-expanded", "false");
        }
      };

      sourceTrigger.addEventListener("click", toggleSourceMenu);

      sourceSearchInput.addEventListener("input", () => {
        renderComboMenu(sourceList, sourceSearchInput.value, true, selectSourceItem);
      });

      sourceSearchInput.addEventListener("keydown", (e) => {
        if (e.key === "Enter") {
          e.preventDefault();
          const first = sourceList.querySelector(".combo-item");
          if (first) {
            const val = first.getAttribute("data-value");
            const lbl = first.querySelector(".combo-item-label")?.textContent || val;
            selectSourceItem({ value: val, label: lbl });
          }
        } else if (e.key === "Escape") {
          sourceContainer.classList.remove("is-open");
          sourceTrigger.setAttribute("aria-expanded", "false");
          sourceTrigger.focus();
        }
      });
    }

    // Configurar Selector Destino (Botón Trigger + Búsqueda dentro del Menú)
    if (targetTrigger && targetContainer && targetSearchInput && targetList && !targetTrigger._boundCombo) {
      targetTrigger._boundCombo = true;

      const selectTargetItem = (item) => {
        if (targetCurrent) targetCurrent.textContent = item.label;
        if (inputTargetLang) {
          inputTargetLang.value = item.value;
          inputTargetLang.dispatchEvent(new Event("change", { bubbles: true }));
        }
        targetContainer.classList.remove("is-open");
        targetTrigger.setAttribute("aria-expanded", "false");
        targetTrigger.focus();
      };

      const toggleTargetMenu = () => {
        const willOpen = !targetContainer.classList.contains("is-open");
        if (sourceContainer) {
          sourceContainer.classList.remove("is-open");
          if (sourceTrigger) sourceTrigger.setAttribute("aria-expanded", "false");
        }
        if (willOpen) {
          targetContainer.classList.add("is-open");
          targetTrigger.setAttribute("aria-expanded", "true");
          targetSearchInput.value = "";
          renderComboMenu(targetList, "", false, selectTargetItem);
          setTimeout(() => {
            targetSearchInput.focus();
          }, 40);
        } else {
          targetContainer.classList.remove("is-open");
          targetTrigger.setAttribute("aria-expanded", "false");
        }
      };

      targetTrigger.addEventListener("click", toggleTargetMenu);

      targetSearchInput.addEventListener("input", () => {
        renderComboMenu(targetList, targetSearchInput.value, false, selectTargetItem);
      });

      targetSearchInput.addEventListener("keydown", (e) => {
        if (e.key === "Enter") {
          e.preventDefault();
          const first = targetList.querySelector(".combo-item");
          if (first) {
            const val = first.getAttribute("data-value");
            const lbl = first.querySelector(".combo-item-label")?.textContent || val;
            selectTargetItem({ value: val, label: lbl });
          }
        } else if (e.key === "Escape") {
          targetContainer.classList.remove("is-open");
          targetTrigger.setAttribute("aria-expanded", "false");
          targetTrigger.focus();
        }
      });
    }

    // Cerrar al hacer clic fuera
    document.addEventListener("pointerdown", (e) => {
      if (sourceContainer && !sourceContainer.contains(e.target)) {
        sourceContainer.classList.remove("is-open");
        if (sourceTrigger) sourceTrigger.setAttribute("aria-expanded", "false");
      }
      if (targetContainer && !targetContainer.contains(e.target)) {
        targetContainer.classList.remove("is-open");
        if (targetTrigger) targetTrigger.setAttribute("aria-expanded", "false");
      }
    });

    // Auto-expansión dinámica de altura
    function autoResizeElement(el) {
      if (!el) return;
      el.style.height = "auto";
      const scrollH = el.scrollHeight;
      const targetH = Math.max(160, Math.min(scrollH + 8, 600));
      el.style.height = targetH + "px";
    }

    // Actualizador de contadores
    function updateCounters() {
      const val = inputText?.value || "";
      const len = val.length;
      const words = val.trim() ? val.trim().split(/\s+/).length : 0;
      if (charCount) charCount.textContent = len + (len === 1 ? " caracter" : " caracteres");
      if (wordCount) wordCount.textContent = words + (words === 1 ? " palabra" : " palabras");
      autoResizeElement(inputText);
    }

    if (inputText && !inputText._boundCount) {
      inputText._boundCount = true;
      inputText.addEventListener("input", updateCounters);
      updateCounters();
    }

    // Intercambiar idiomas (Swap)
    if (btnSwapLang && !btnSwapLang._bound) {
      btnSwapLang._bound = true;
      btnSwapLang.addEventListener("click", () => {
        // Animación de giro de 360 grados
        btnSwapLang.classList.remove("btn-swap-spin");
        void btnSwapLang.offsetWidth;
        btnSwapLang.classList.add("btn-swap-spin");
        setTimeout(() => btnSwapLang.classList.remove("btn-swap-spin"), 460);

        const src = inputSourceLang?.value || "auto";
        const tgt = inputTargetLang?.value || "en";

        let newSrc = "auto";
        let newTgt = "en";
        
        if (src === "auto") {
          newSrc = tgt;
          newTgt = tgt === "es" ? "en" : "es";
        } else {
          newSrc = tgt;
          newTgt = src;
        }

        if (inputSourceLang) inputSourceLang.value = newSrc;
        if (inputTargetLang) inputTargetLang.value = newTgt;

        if (sourceCurrent && langLabelMap.has(newSrc.toLowerCase())) {
          sourceCurrent.textContent = langLabelMap.get(newSrc.toLowerCase());
        }
        if (targetCurrent && langLabelMap.has(newTgt.toLowerCase())) {
          targetCurrent.textContent = langLabelMap.get(newTgt.toLowerCase());
        }

        const outTxt = outputText?.textContent || "";
        if (outTxt && !outTxt.startsWith("Haz clic") && !outTxt.startsWith("Error") && !outTxt.startsWith("Traduciendo")) {
          if (inputText) {
            inputText.value = outTxt.trim();
            updateCounters();
          }
        }
      });
    }

    // Botón Limpiar Texto (Solo Icono con Wiggle y Feedback)
    if (btnClearInput && !btnClearInput._bound) {
      btnClearInput._bound = true;
      btnClearInput.addEventListener("click", () => {
        // Animación y Tooltip temporal
        btnClearInput.classList.remove("btn-wiggle-active");
        void btnClearInput.offsetWidth;
        btnClearInput.classList.add("btn-wiggle-active");
        btnClearInput.setAttribute("data-tooltip", "¡Limpiado!");
        setTimeout(() => {
          btnClearInput.classList.remove("btn-wiggle-active");
          btnClearInput.setAttribute("data-tooltip", "Limpiar texto");
        }, 1200);

        if (inputText) {
          inputText.value = "";
          inputText.focus();
        }
        updateCounters();
      });
    }

    // Control de bloqueo de UI durante ejecución
    function setTranslatorLock(isTranslating) {
      if (inputText) {
        inputText.readOnly = isTranslating;
        inputText.style.cursor = isTranslating ? "not-allowed" : "text";
        inputText.style.opacity = isTranslating ? "0.6" : "1";
      }
      if (sourceTrigger) {
        sourceTrigger.disabled = isTranslating;
        sourceTrigger.style.pointerEvents = isTranslating ? "none" : "auto";
        sourceTrigger.style.opacity = isTranslating ? "0.6" : "1";
      }
      if (targetTrigger) {
        targetTrigger.disabled = isTranslating;
        targetTrigger.style.pointerEvents = isTranslating ? "none" : "auto";
        targetTrigger.style.opacity = isTranslating ? "0.6" : "1";
      }
      if (sourceSearchInput) sourceSearchInput.disabled = isTranslating;
      if (targetSearchInput) targetSearchInput.disabled = isTranslating;
      if (btnSwapLang) btnSwapLang.disabled = isTranslating;
      if (btnRun) {
        btnRun.disabled = isTranslating;
        btnRun.style.cursor = isTranslating ? "not-allowed" : "pointer";
        btnRun.style.opacity = isTranslating ? "0.75" : "1";
        
        if (isTranslating) {
          btnRun.innerHTML = ICON_LOADING + ' <span id="btn-run-translator-text">Traduciendo...</span>';
        }
      }
    }

    // Configuración de descarga de archivo .txt
    function updateDownloadLink(translatedText) {
      if (!btnDownloadResult) return;
      if (!translatedText || translatedText.startsWith("Haz clic") || translatedText.startsWith("Error")) {
        btnDownloadResult.style.display = "none";
        return;
      }
      btnDownloadResult.style.display = "inline-flex";
      btnDownloadResult.onclick = () => {
        // Animación de rebote y tooltip temporal
        btnDownloadResult.classList.remove("btn-download-active");
        void btnDownloadResult.offsetWidth;
        btnDownloadResult.classList.add("btn-download-active");
        btnDownloadResult.setAttribute("data-tooltip", "¡Descargado!");
        setTimeout(() => {
          btnDownloadResult.classList.remove("btn-download-active");
          btnDownloadResult.setAttribute("data-tooltip", "Descargar .txt");
        }, 1500);

        const blob = new Blob([translatedText], { type: "text/plain;charset=utf-8" });
        const url = URL.createObjectURL(blob);
        const a = document.createElement("a");
        a.href = url;
        a.download = "traduccion.txt";
        document.body.appendChild(a);
        a.click();
        document.body.removeChild(a);
        URL.revokeObjectURL(url);
      };
    }

    // Renderizar JSON sin downloadUrl
    function renderJsonWithoutDownload(data) {
      if (!outputJson) return;
      const cleanData = Object.assign({}, data);
      delete cleanData.downloadUrl;
      outputJson.textContent = JSON.stringify(cleanData, null, 2);
    }

    // 3. Ejecutar Traducción en Vivo
    if (btnRun && !btnRun._bound) {
      btnRun._bound = true;
      btnRun.addEventListener("click", async () => {
        const text = (inputText?.value || "").trim();
        const to = inputTargetLang?.value || "en";
        const from = inputSourceLang?.value || "auto";

        if (!text) {
          if (inputText) inputText.focus();
          return;
        }

        const cacheKey = from + ":" + to + ":" + text;
        if (translatorClientCache.has(cacheKey)) {
          const cached = translatorClientCache.get(cacheKey);
          renderJsonWithoutDownload(cached);
          if (outputText) {
            outputText.textContent = cached.translatedText || text;
            autoResizeElement(outputText);
          }
          if (stats) {
            stats.textContent = "Éxito • 0ms (Caché)";
            stats.style.color = "#10b981";
          }
          updateDownloadLink(cached.translatedText || text);
          return;
        }

        setTranslatorLock(true);
        if (outputText) outputText.textContent = "Traduciendo a través del motor neural Vork...";
        if (stats) {
          stats.textContent = "Conectando API...";
          stats.style.color = "var(--primary)";
        }
        const t0 = performance.now();

        try {
          const payload = { text, targetLanguage: to };
          if (from && from !== "auto") {
            payload.sourceLanguage = from;
          }

          const resp = await fetch("/api/translate", {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify(payload)
          });

          const latency = Math.round(performance.now() - t0);
          const data = await resp.json();

          renderJsonWithoutDownload(data);

          if (data.translatedText) {
            translatorClientCache.set(cacheKey, data);
            if (outputText) {
              outputText.textContent = data.translatedText;
              autoResizeElement(outputText);
            }
            if (stats) {
              stats.textContent = "Éxito • " + latency + "ms";
              stats.style.color = "#10b981";
            }
            updateDownloadLink(data.translatedText);

            if (btnRun) {
              btnRun.innerHTML = ICON_CHECK + ' <span id="btn-run-translator-text">¡Traducido!</span>';
              setTimeout(() => {
                btnRun.innerHTML = ICON_TRANSLATE + ' <span id="btn-run-translator-text">TRADUCIR TEXTO</span>';
                setTranslatorLock(false);
              }, 1800);
              return;
            }
          } else {
            if (outputText) outputText.textContent = "Error al recibir respuesta: " + (data.error || "Formato de respuesta inválido");
            if (stats) {
              stats.textContent = "Error en respuesta de la API";
              stats.style.color = "#ef4444";
            }
            updateDownloadLink(null);
          }
        } catch (err) {
          if (outputText) outputText.textContent = "Error de conexión: " + err.message;
          if (outputJson) outputJson.textContent = JSON.stringify({ error: err.message }, null, 2);
          if (stats) {
            stats.textContent = "Fallo de conexión de red";
            stats.style.color = "#ef4444";
          }
          updateDownloadLink(null);
        } finally {
          if (!btnRun.innerHTML.includes("check-pop-icon")) {
            btnRun.innerHTML = ICON_TRANSLATE + ' <span id="btn-run-translator-text">TRADUCIR TEXTO</span>';
            setTranslatorLock(false);
          }
        }
      });
    }

    // Copiar resultado traducido (Botón solo icono con tooltip dinámico)
    if (btnCopyResult && !btnCopyResult._bound) {
      btnCopyResult._bound = true;
      btnCopyResult.addEventListener("click", () => {
        const txt = outputText?.textContent;
        if (txt && !txt.startsWith("Haz clic") && !txt.startsWith("Error") && !txt.startsWith("Traduciendo")) {
          navigator.clipboard.writeText(txt);
          btnCopyResult.setAttribute("data-tooltip", "¡Copiado!");
          btnCopyResult.innerHTML = ICON_COPY_SUCCESS;
          setTimeout(() => {
            btnCopyResult.setAttribute("data-tooltip", "Copiar Resultado");
            btnCopyResult.innerHTML = ICON_COPY_DEFAULT;
          }, 1800);
        }
      });
    }

    // Copiar comando del banner de instalación inferior
    if (btnCopyInstall && !btnCopyInstall._bound) {
      btnCopyInstall._bound = true;
      btnCopyInstall.addEventListener("click", () => {
        const cmdEl = document.getElementById("cli-install-cmd");
        const cmd = cmdEl?.textContent?.trim() || "irm https://vork-st1k.onrender.com/cli/install.ps1 | iex";
        navigator.clipboard.writeText(cmd);
        const originalHtml = btnCopyInstall.innerHTML;
        btnCopyInstall.innerHTML = '<svg class="icon" viewBox="0 0 24 24" width="14" height="14" stroke="#10b981" fill="none" stroke-width="2.5"><path d="M20 6L9 17l-5-5"/></svg> <span>¡Copiado!</span>';
        setTimeout(() => {
          btnCopyInstall.innerHTML = originalHtml;
        }, 1800);
      });
    }

    // Pestañas de Código (Frontend & Backend)
    const tabButtons = document.querySelectorAll(".code-tab-btn");
    tabButtons.forEach(btn => {
      if (btn._boundTab) return;
      btn._boundTab = true;
      btn.addEventListener("click", () => {
        const group = btn.getAttribute("data-tab-group");
        const targetId = btn.getAttribute("data-tab-target");
        if (!group || !targetId) return;

        // Desactivar botones del grupo
        document.querySelectorAll(`.code-tab-btn[data-tab-group="${group}"]`).forEach(b => {
          b.classList.remove("is-active");
        });
        btn.classList.add("is-active");

        // Ocultar paneles y mostrar el seleccionado
        const parentBox = btn.closest(".code-box-wrapper");
        if (parentBox) {
          parentBox.querySelectorAll(".code-tab-panel").forEach(panel => {
            panel.classList.remove("is-active");
          });
          const targetPanel = document.getElementById(targetId);
          if (targetPanel) targetPanel.classList.add("is-active");
        }
      });
    });

    // Copiar Bloques de Código de Integración con Animación y Feedback
    const codeCopyButtons = document.querySelectorAll(".btn-code-copy");
    codeCopyButtons.forEach(btn => {
      if (btn._boundCopy) return;
      btn._boundCopy = true;
      btn.addEventListener("click", () => {
        let textToCopy = "";
        const targetId = btn.getAttribute("data-copy-target");
        const activeGroup = btn.getAttribute("data-copy-active");

        if (targetId) {
          const el = document.getElementById(targetId);
          textToCopy = el?.textContent || "";
        } else if (activeGroup) {
          const parentBox = btn.closest(".code-box-wrapper");
          const activePanel = parentBox ? parentBox.querySelector(".code-tab-panel.is-active pre") : null;
          textToCopy = activePanel?.textContent || "";
        }

        if (!textToCopy) return;

        navigator.clipboard.writeText(textToCopy);
        const originalHtml = btn.innerHTML;
        btn.classList.add("is-copied");
        btn.innerHTML = '<svg class="icon" viewBox="0 0 24 24" width="13" height="13" stroke="#10b981" fill="none" stroke-width="2.6"><path d="M20 6L9 17l-5-5"/></svg> <span class="btn-copy-label">¡Copiado!</span>';
        setTimeout(() => {
          btn.innerHTML = originalHtml;
          btn.classList.remove("is-copied");
        }, 1800);
      });
    });
  }

  window.initTranslatorModule = initTranslatorModule;

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", initTranslatorModule);
  } else {
    initTranslatorModule();
  }
})(window, document);
