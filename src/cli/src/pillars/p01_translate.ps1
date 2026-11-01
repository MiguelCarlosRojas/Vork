<#
.SYNOPSIS
    Pilar 01: Vork Traductor Neuronal en la Nube (+200 Idiomas)
#>

function Get-VorkTranslateLanguages {
    if ($global:VorkTranslateLanguages -and $global:VorkTranslateLanguages.Count -gt 0) { return $global:VorkTranslateLanguages }
    $raw = @(
        @{ Value = "en"; Label = "en (Inglés)"; Search = "en inglés english" },
        @{ Value = "es"; Label = "es (Español)"; Search = "es español spanish" },
        @{ Value = "fr"; Label = "fr (Francés)"; Search = "fr francés french" },
        @{ Value = "de"; Label = "de (Alemán)"; Search = "de alemán german" },
        @{ Value = "it"; Label = "it (Italiano)"; Search = "it italiano italian" },
        @{ Value = "pt"; Label = "pt (Portugués)"; Search = "pt portugués portuguese (brazil)" },
        @{ Value = "ja"; Label = "ja (Japonés)"; Search = "ja japonés japanese" },
        @{ Value = "zh-CN"; Label = "zh-CN (Chino (Simplificado))"; Search = "zh-cn chino (simplificado) chinese (simplified)" },
        @{ Value = "ru"; Label = "ru (Ruso)"; Search = "ru ruso russian" },
        @{ Value = "ko"; Label = "ko (Coreano)"; Search = "ko coreano korean" },
        @{ Value = "aa"; Label = "aa (Afar)"; Search = "aa afar afar" },
        @{ Value = "ab"; Label = "ab (Abkhaz)"; Search = "ab abkhaz abkhaz" },
        @{ Value = "ace"; Label = "ace (Acehnese)"; Search = "ace acehnese acehnese" },
        @{ Value = "ach"; Label = "ach (Acholi)"; Search = "ach acholi acholi" },
        @{ Value = "af"; Label = "af (Afrikáans)"; Search = "af afrikáans afrikaans" },
        @{ Value = "ak"; Label = "ak (Twi)"; Search = "ak twi twi" },
        @{ Value = "alz"; Label = "alz (Alur)"; Search = "alz alur alur" },
        @{ Value = "am"; Label = "am (Amhárico)"; Search = "am amhárico amharic" },
        @{ Value = "ar"; Label = "ar (Árabe)"; Search = "ar árabe arabic" },
        @{ Value = "as"; Label = "as (Assamese)"; Search = "as assamese assamese" },
        @{ Value = "av"; Label = "av (Avar)"; Search = "av avar avar" },
        @{ Value = "awa"; Label = "awa (Awadhi)"; Search = "awa awadhi awadhi" },
        @{ Value = "ay"; Label = "ay (Aimara)"; Search = "ay aimara aymara" },
        @{ Value = "az"; Label = "az (Azerbaiyano)"; Search = "az azerbaiyano azerbaijani" },
        @{ Value = "ba"; Label = "ba (Bashkir)"; Search = "ba bashkir bashkir" },
        @{ Value = "bal"; Label = "bal (Baluchi)"; Search = "bal baluchi baluchi" },
        @{ Value = "ban"; Label = "ban (Balinese)"; Search = "ban balinese balinese" },
        @{ Value = "bbc"; Label = "bbc (Batak Toba)"; Search = "bbc batak toba batak toba" },
        @{ Value = "bci"; Label = "bci (Baoulé)"; Search = "bci baoulé baoulé" },
        @{ Value = "be"; Label = "be (Bielorruso)"; Search = "be bielorruso belarusian" },
        @{ Value = "bem"; Label = "bem (Bemba)"; Search = "bem bemba bemba" },
        @{ Value = "ber"; Label = "ber (Tamazight (Tifinagh))"; Search = "ber tamazight (tifinagh) tamazight (tifinagh)" },
        @{ Value = "ber-Latn"; Label = "ber-Latn (Tamazight)"; Search = "ber-latn tamazight tamazight" },
        @{ Value = "bew"; Label = "bew (Betawi)"; Search = "bew betawi betawi" },
        @{ Value = "bg"; Label = "bg (Búlgaro)"; Search = "bg búlgaro bulgarian" },
        @{ Value = "bho"; Label = "bho (Bhojpuri)"; Search = "bho bhojpuri bhojpuri" },
        @{ Value = "bik"; Label = "bik (Bikol)"; Search = "bik bikol bikol" },
        @{ Value = "bm"; Label = "bm (Bambara)"; Search = "bm bambara bambara" },
        @{ Value = "bm-Nkoo"; Label = "bm-Nkoo (NKo)"; Search = "bm-nkoo nko nko" },
        @{ Value = "bn"; Label = "bn (Bengalí)"; Search = "bn bengalí bengali" },
        @{ Value = "bo"; Label = "bo (Tibetan)"; Search = "bo tibetan tibetan" },
        @{ Value = "br"; Label = "br (Breton)"; Search = "br breton breton" },
        @{ Value = "bs"; Label = "bs (Bosnio)"; Search = "bs bosnio bosnian" },
        @{ Value = "bts"; Label = "bts (Batak Simalungun)"; Search = "bts batak simalungun batak simalungun" },
        @{ Value = "btx"; Label = "btx (Batak Karo)"; Search = "btx batak karo batak karo" },
        @{ Value = "bua"; Label = "bua (Buryat)"; Search = "bua buryat buryat" },
        @{ Value = "ca"; Label = "ca (Catalán)"; Search = "ca catalán catalan" },
        @{ Value = "ce"; Label = "ce (Chechen)"; Search = "ce chechen chechen" },
        @{ Value = "ceb"; Label = "ceb (Cebuano)"; Search = "ceb cebuano cebuano" },
        @{ Value = "cgg"; Label = "cgg (Kiga)"; Search = "cgg kiga kiga" },
        @{ Value = "ch"; Label = "ch (Chamorro)"; Search = "ch chamorro chamorro" },
        @{ Value = "chk"; Label = "chk (Chuukese)"; Search = "chk chuukese chuukese" },
        @{ Value = "chm"; Label = "chm (Meadow Mari)"; Search = "chm meadow mari meadow mari" },
        @{ Value = "ckb"; Label = "ckb (Kurdish (Sorani))"; Search = "ckb kurdish (sorani) kurdish (sorani)" },
        @{ Value = "cnh"; Label = "cnh (Hakha Chin)"; Search = "cnh hakha chin hakha chin" },
        @{ Value = "co"; Label = "co (Corso)"; Search = "co corso corsican" },
        @{ Value = "crh"; Label = "crh (Crimean Tatar (Cyrillic))"; Search = "crh crimean tatar (cyrillic) crimean tatar (cyrillic)" },
        @{ Value = "crh-Latn"; Label = "crh-Latn (Crimean Tatar (Latin))"; Search = "crh-latn crimean tatar (latin) crimean tatar (latin)" },
        @{ Value = "crs"; Label = "crs (Seychellois Creole)"; Search = "crs seychellois creole seychellois creole" },
        @{ Value = "cs"; Label = "cs (Checo)"; Search = "cs checo czech" },
        @{ Value = "cv"; Label = "cv (Chuvash)"; Search = "cv chuvash chuvash" },
        @{ Value = "cy"; Label = "cy (Galés)"; Search = "cy galés welsh" },
        @{ Value = "da"; Label = "da (Danés)"; Search = "da danés danish" },
        @{ Value = "din"; Label = "din (Dinka)"; Search = "din dinka dinka" },
        @{ Value = "doi"; Label = "doi (Dogri)"; Search = "doi dogri dogri" },
        @{ Value = "dov"; Label = "dov (Dombe)"; Search = "dov dombe dombe" },
        @{ Value = "dv"; Label = "dv (Dhivehi)"; Search = "dv dhivehi dhivehi" },
        @{ Value = "dyu"; Label = "dyu (Dyula)"; Search = "dyu dyula dyula" },
        @{ Value = "dz"; Label = "dz (Dzongkha)"; Search = "dz dzongkha dzongkha" },
        @{ Value = "ee"; Label = "ee (Ewe)"; Search = "ee ewe ewe" },
        @{ Value = "el"; Label = "el (Griego)"; Search = "el griego greek" },
        @{ Value = "eo"; Label = "eo (Esperanto)"; Search = "eo esperanto esperanto" },
        @{ Value = "et"; Label = "et (Estonio)"; Search = "et estonio estonian" },
        @{ Value = "eu"; Label = "eu (Vasco / Euskera)"; Search = "eu vasco / euskera basque" },
        @{ Value = "fa"; Label = "fa (Persa)"; Search = "fa persa persian" },
        @{ Value = "fa-AF"; Label = "fa-AF (Dari)"; Search = "fa-af dari dari" },
        @{ Value = "ff"; Label = "ff (Fulani)"; Search = "ff fulani fulani" },
        @{ Value = "fi"; Label = "fi (Finlandés)"; Search = "fi finlandés finnish" },
        @{ Value = "fj"; Label = "fj (Fijian)"; Search = "fj fijian fijian" },
        @{ Value = "fo"; Label = "fo (Faroese)"; Search = "fo faroese faroese" },
        @{ Value = "fon"; Label = "fon (Fon)"; Search = "fon fon fon" },
        @{ Value = "fr-CA"; Label = "fr-CA (French (Canada))"; Search = "fr-ca french (canada) french (canada)" },
        @{ Value = "fur"; Label = "fur (Friulian)"; Search = "fur friulian friulian" },
        @{ Value = "fy"; Label = "fy (Frisón)"; Search = "fy frisón frisian" },
        @{ Value = "ga"; Label = "ga (Irlandés)"; Search = "ga irlandés irish" },
        @{ Value = "gaa"; Label = "gaa (Ga)"; Search = "gaa ga ga" },
        @{ Value = "gd"; Label = "gd (Gaélico escocés)"; Search = "gd gaélico escocés scots gaelic" },
        @{ Value = "gl"; Label = "gl (Gallego)"; Search = "gl gallego galician" },
        @{ Value = "gn"; Label = "gn (Guaraní)"; Search = "gn guaraní guarani" },
        @{ Value = "gom"; Label = "gom (Konkani)"; Search = "gom konkani konkani" },
        @{ Value = "gu"; Label = "gu (Guyaratí)"; Search = "gu guyaratí gujarati" },
        @{ Value = "gv"; Label = "gv (Manx)"; Search = "gv manx manx" },
        @{ Value = "ha"; Label = "ha (Hausa)"; Search = "ha hausa hausa" },
        @{ Value = "haw"; Label = "haw (Hawaiano)"; Search = "haw hawaiano hawaiian" },
        @{ Value = "he"; Label = "he (Hebreo)"; Search = "he hebreo hebrew" },
        @{ Value = "hi"; Label = "hi (Hindi)"; Search = "hi hindi hindi" },
        @{ Value = "hil"; Label = "hil (Hiligaynon)"; Search = "hil hiligaynon hiligaynon" },
        @{ Value = "hmn"; Label = "hmn (Hmong)"; Search = "hmn hmong hmong" },
        @{ Value = "hr"; Label = "hr (Croata)"; Search = "hr croata croatian" },
        @{ Value = "hrx"; Label = "hrx (Hunsrik)"; Search = "hrx hunsrik hunsrik" },
        @{ Value = "ht"; Label = "ht (Criollo haitiano)"; Search = "ht criollo haitiano haitian creole" },
        @{ Value = "hu"; Label = "hu (Húngaro)"; Search = "hu húngaro hungarian" },
        @{ Value = "hy"; Label = "hy (Armenio)"; Search = "hy armenio armenian" },
        @{ Value = "iba"; Label = "iba (Iban)"; Search = "iba iban iban" },
        @{ Value = "id"; Label = "id (Indonesio)"; Search = "id indonesio indonesian" },
        @{ Value = "ig"; Label = "ig (Igbo)"; Search = "ig igbo igbo" },
        @{ Value = "ilo"; Label = "ilo (Ilocano)"; Search = "ilo ilocano ilocano" },
        @{ Value = "is"; Label = "is (Islandés)"; Search = "is islandés icelandic" },
        @{ Value = "iu"; Label = "iu (Inuktut (Syllabics))"; Search = "iu inuktut (syllabics) inuktut (syllabics)" },
        @{ Value = "iu-Latn"; Label = "iu-Latn (Inuktut (Latin))"; Search = "iu-latn inuktut (latin) inuktut (latin)" },
        @{ Value = "iw"; Label = "iw (Hebrew)"; Search = "iw hebrew hebrew" },
        @{ Value = "jam"; Label = "jam (Jamaican Patois)"; Search = "jam jamaican patois jamaican patois" },
        @{ Value = "jw"; Label = "jw (Javanese)"; Search = "jw javanese javanese" },
        @{ Value = "ka"; Label = "ka (Georgiano)"; Search = "ka georgiano georgian" },
        @{ Value = "kac"; Label = "kac (Jingpo)"; Search = "kac jingpo jingpo" },
        @{ Value = "kek"; Label = "kek (Qʼeqchiʼ)"; Search = "kek qʼeqchiʼ qʼeqchiʼ" },
        @{ Value = "kg"; Label = "kg (Kikongo)"; Search = "kg kikongo kikongo" },
        @{ Value = "kha"; Label = "kha (Khasi)"; Search = "kha khasi khasi" },
        @{ Value = "kk"; Label = "kk (Kazajo)"; Search = "kk kazajo kazakh" },
        @{ Value = "kl"; Label = "kl (Kalaallisut)"; Search = "kl kalaallisut kalaallisut" },
        @{ Value = "km"; Label = "km (Jemer)"; Search = "km jemer khmer" },
        @{ Value = "kn"; Label = "kn (Canarés / Kannada)"; Search = "kn canarés / kannada kannada" },
        @{ Value = "kr"; Label = "kr (Kanuri)"; Search = "kr kanuri kanuri" },
        @{ Value = "kri"; Label = "kri (Krio)"; Search = "kri krio krio" },
        @{ Value = "ktu"; Label = "ktu (Kituba)"; Search = "ktu kituba kituba" },
        @{ Value = "ku"; Label = "ku (Kurdo)"; Search = "ku kurdo kurdish (kurmanji)" },
        @{ Value = "kv"; Label = "kv (Komi)"; Search = "kv komi komi" },
        @{ Value = "ky"; Label = "ky (Kirguís)"; Search = "ky kirguís kyrgyz" },
        @{ Value = "la"; Label = "la (Latín)"; Search = "la latín latin" },
        @{ Value = "lb"; Label = "lb (Luxemburgués)"; Search = "lb luxemburgués luxembourgish" },
        @{ Value = "lg"; Label = "lg (Luganda)"; Search = "lg luganda luganda" },
        @{ Value = "li"; Label = "li (Limburgish)"; Search = "li limburgish limburgish" },
        @{ Value = "lij"; Label = "lij (Ligurian)"; Search = "lij ligurian ligurian" },
        @{ Value = "lmo"; Label = "lmo (Lombard)"; Search = "lmo lombard lombard" },
        @{ Value = "ln"; Label = "ln (Lingala)"; Search = "ln lingala lingala" },
        @{ Value = "lo"; Label = "lo (Laosiano)"; Search = "lo laosiano lao" },
        @{ Value = "lt"; Label = "lt (Lituano)"; Search = "lt lituano lithuanian" },
        @{ Value = "ltg"; Label = "ltg (Latgalian)"; Search = "ltg latgalian latgalian" },
        @{ Value = "lua"; Label = "lua (Tshiluba)"; Search = "lua tshiluba tshiluba" },
        @{ Value = "luo"; Label = "luo (Luo)"; Search = "luo luo luo" },
        @{ Value = "lus"; Label = "lus (Mizo)"; Search = "lus mizo mizo" },
        @{ Value = "lv"; Label = "lv (Letón)"; Search = "lv letón latvian" },
        @{ Value = "mad"; Label = "mad (Madurese)"; Search = "mad madurese madurese" },
        @{ Value = "mai"; Label = "mai (Maithili)"; Search = "mai maithili maithili" },
        @{ Value = "mak"; Label = "mak (Makassar)"; Search = "mak makassar makassar" },
        @{ Value = "mam"; Label = "mam (Mam)"; Search = "mam mam mam" },
        @{ Value = "mfe"; Label = "mfe (Mauritian Creole)"; Search = "mfe mauritian creole mauritian creole" },
        @{ Value = "mg"; Label = "mg (Malgache)"; Search = "mg malgache malagasy" },
        @{ Value = "mh"; Label = "mh (Marshallese)"; Search = "mh marshallese marshallese" },
        @{ Value = "mi"; Label = "mi (Maorí)"; Search = "mi maorí maori" },
        @{ Value = "min"; Label = "min (Minang)"; Search = "min minang minang" },
        @{ Value = "mk"; Label = "mk (Macedonio)"; Search = "mk macedonio macedonian" },
        @{ Value = "ml"; Label = "ml (Malayalam)"; Search = "ml malayalam malayalam" },
        @{ Value = "mn"; Label = "mn (Mongol)"; Search = "mn mongol mongolian" },
        @{ Value = "mni-Mtei"; Label = "mni-Mtei (Meiteilon (Manipuri))"; Search = "mni-mtei meiteilon (manipuri) meiteilon (manipuri)" },
        @{ Value = "mr"; Label = "mr (Maratí)"; Search = "mr maratí marathi" },
        @{ Value = "ms"; Label = "ms (Malayo)"; Search = "ms malayo malay" },
        @{ Value = "ms-Arab"; Label = "ms-Arab (Malay (Jawi))"; Search = "ms-arab malay (jawi) malay (jawi)" },
        @{ Value = "mt"; Label = "mt (Maltés)"; Search = "mt maltés maltese" },
        @{ Value = "mwr"; Label = "mwr (Marwadi)"; Search = "mwr marwadi marwadi" },
        @{ Value = "my"; Label = "my (Birmano)"; Search = "my birmano myanmar (burmese)" },
        @{ Value = "ndc-ZW"; Label = "ndc-ZW (Ndau)"; Search = "ndc-zw ndau ndau" },
        @{ Value = "ne"; Label = "ne (Nepalí)"; Search = "ne nepalí nepali" },
        @{ Value = "new"; Label = "new (Nepalbhasa (Newari))"; Search = "new nepalbhasa (newari) nepalbhasa (newari)" },
        @{ Value = "nhe"; Label = "nhe (Nahuatl (Eastern Huasteca))"; Search = "nhe nahuatl (eastern huasteca) nahuatl (eastern huasteca)" },
        @{ Value = "nl"; Label = "nl (Holandés / Neerlandés)"; Search = "nl holandés / neerlandés dutch" },
        @{ Value = "no"; Label = "no (Noruego)"; Search = "no noruego norwegian" },
        @{ Value = "nr"; Label = "nr (Ndebele (South))"; Search = "nr ndebele (south) ndebele (south)" },
        @{ Value = "nso"; Label = "nso (Sepedi)"; Search = "nso sepedi sepedi" },
        @{ Value = "nus"; Label = "nus (Nuer)"; Search = "nus nuer nuer" },
        @{ Value = "ny"; Label = "ny (Chichewa)"; Search = "ny chichewa chichewa" },
        @{ Value = "oc"; Label = "oc (Occitan)"; Search = "oc occitan occitan" },
        @{ Value = "om"; Label = "om (Oromo)"; Search = "om oromo oromo" },
        @{ Value = "or"; Label = "or (Odia)"; Search = "or odia odia (oriya)" },
        @{ Value = "os"; Label = "os (Ossetian)"; Search = "os ossetian ossetian" },
        @{ Value = "pa"; Label = "pa (Panyabí)"; Search = "pa panyabí punjabi (gurmukhi)" },
        @{ Value = "pa-Arab"; Label = "pa-Arab (Punjabi (Shahmukhi))"; Search = "pa-arab punjabi (shahmukhi) punjabi (shahmukhi)" },
        @{ Value = "pag"; Label = "pag (Pangasinan)"; Search = "pag pangasinan pangasinan" },
        @{ Value = "pam"; Label = "pam (Kapampangan)"; Search = "pam kapampangan kapampangan" },
        @{ Value = "pap"; Label = "pap (Papiamento)"; Search = "pap papiamento papiamento" },
        @{ Value = "pl"; Label = "pl (Polaco)"; Search = "pl polaco polish" },
        @{ Value = "ps"; Label = "ps (Pastún)"; Search = "ps pastún pashto" },
        @{ Value = "pt-PT"; Label = "pt-PT (Portuguese (Portugal))"; Search = "pt-pt portuguese (portugal) portuguese (portugal)" },
        @{ Value = "qu"; Label = "qu (Quechua)"; Search = "qu quechua quechua" },
        @{ Value = "rn"; Label = "rn (Rundi)"; Search = "rn rundi rundi" },
        @{ Value = "ro"; Label = "ro (Rumano)"; Search = "ro rumano romanian" },
        @{ Value = "rom"; Label = "rom (Romani)"; Search = "rom romani romani" },
        @{ Value = "rw"; Label = "rw (Kinyarwanda)"; Search = "rw kinyarwanda kinyarwanda" },
        @{ Value = "sa"; Label = "sa (Sanskrit)"; Search = "sa sanskrit sanskrit" },
        @{ Value = "sah"; Label = "sah (Yakut)"; Search = "sah yakut yakut" },
        @{ Value = "sat"; Label = "sat (Santali (Ol Chiki))"; Search = "sat santali (ol chiki) santali (ol chiki)" },
        @{ Value = "sat-Latn"; Label = "sat-Latn (Santali (Latin))"; Search = "sat-latn santali (latin) santali (latin)" },
        @{ Value = "scn"; Label = "scn (Sicilian)"; Search = "scn sicilian sicilian" },
        @{ Value = "sd"; Label = "sd (Sindhi)"; Search = "sd sindhi sindhi" },
        @{ Value = "se"; Label = "se (Sami (North))"; Search = "se sami (north) sami (north)" },
        @{ Value = "sg"; Label = "sg (Sango)"; Search = "sg sango sango" },
        @{ Value = "shn"; Label = "shn (Shan)"; Search = "shn shan shan" },
        @{ Value = "si"; Label = "si (Cingalés)"; Search = "si cingalés sinhala" },
        @{ Value = "sk"; Label = "sk (Eslovaco)"; Search = "sk eslovaco slovak" },
        @{ Value = "sl"; Label = "sl (Esloveno)"; Search = "sl esloveno slovenian" },
        @{ Value = "sm"; Label = "sm (Samoano)"; Search = "sm samoano samoan" },
        @{ Value = "sn"; Label = "sn (Shona)"; Search = "sn shona shona" },
        @{ Value = "so"; Label = "so (Somalí)"; Search = "so somalí somali" },
        @{ Value = "sq"; Label = "sq (Albanés)"; Search = "sq albanés albanian" },
        @{ Value = "sr"; Label = "sr (Serbio)"; Search = "sr serbio serbian" },
        @{ Value = "ss"; Label = "ss (Swati)"; Search = "ss swati swati" },
        @{ Value = "st"; Label = "st (Sesoto)"; Search = "st sesoto sesotho" },
        @{ Value = "su"; Label = "su (Sundanés)"; Search = "su sundanés sundanese" },
        @{ Value = "sus"; Label = "sus (Susu)"; Search = "sus susu susu" },
        @{ Value = "sv"; Label = "sv (Sueco)"; Search = "sv sueco swedish" },
        @{ Value = "sw"; Label = "sw (Suajili)"; Search = "sw suajili swahili" },
        @{ Value = "szl"; Label = "szl (Silesian)"; Search = "szl silesian silesian" },
        @{ Value = "ta"; Label = "ta (Tamil)"; Search = "ta tamil tamil" },
        @{ Value = "tcy"; Label = "tcy (Tulu)"; Search = "tcy tulu tulu" },
        @{ Value = "te"; Label = "te (Telugu)"; Search = "te telugu telugu" },
        @{ Value = "tet"; Label = "tet (Tetum)"; Search = "tet tetum tetum" },
        @{ Value = "tg"; Label = "tg (Tayiko)"; Search = "tg tayiko tajik" },
        @{ Value = "th"; Label = "th (Tailandés)"; Search = "th tailandés thai" },
        @{ Value = "ti"; Label = "ti (Tigrinya)"; Search = "ti tigrinya tigrinya" },
        @{ Value = "tiv"; Label = "tiv (Tiv)"; Search = "tiv tiv tiv" },
        @{ Value = "tk"; Label = "tk (Turcomano)"; Search = "tk turcomano turkmen" },
        @{ Value = "tl"; Label = "tl (Tagalo / Filipino)"; Search = "tl tagalo / filipino filipino" },
        @{ Value = "tn"; Label = "tn (Tswana)"; Search = "tn tswana tswana" },
        @{ Value = "to"; Label = "to (Tongan)"; Search = "to tongan tongan" },
        @{ Value = "tpi"; Label = "tpi (Tok Pisin)"; Search = "tpi tok pisin tok pisin" },
        @{ Value = "tr"; Label = "tr (Turco)"; Search = "tr turco turkish" },
        @{ Value = "trp"; Label = "trp (Kokborok)"; Search = "trp kokborok kokborok" },
        @{ Value = "ts"; Label = "ts (Tsonga)"; Search = "ts tsonga tsonga" },
        @{ Value = "tt"; Label = "tt (Tártaro)"; Search = "tt tártaro tatar" },
        @{ Value = "tum"; Label = "tum (Tumbuka)"; Search = "tum tumbuka tumbuka" },
        @{ Value = "ty"; Label = "ty (Tahitian)"; Search = "ty tahitian tahitian" },
        @{ Value = "tyv"; Label = "tyv (Tuvan)"; Search = "tyv tuvan tuvan" },
        @{ Value = "udm"; Label = "udm (Udmurt)"; Search = "udm udmurt udmurt" },
        @{ Value = "ug"; Label = "ug (Uigur)"; Search = "ug uigur uyghur" },
        @{ Value = "uk"; Label = "uk (Ucraniano)"; Search = "uk ucraniano ukrainian" },
        @{ Value = "ur"; Label = "ur (Urdu)"; Search = "ur urdu urdu" },
        @{ Value = "uz"; Label = "uz (Uzbeko)"; Search = "uz uzbeko uzbek" },
        @{ Value = "ve"; Label = "ve (Venda)"; Search = "ve venda venda" },
        @{ Value = "vec"; Label = "vec (Venetian)"; Search = "vec venetian venetian" },
        @{ Value = "vi"; Label = "vi (Vietnamita)"; Search = "vi vietnamita vietnamese" },
        @{ Value = "war"; Label = "war (Waray)"; Search = "war waray waray" },
        @{ Value = "wo"; Label = "wo (Wolof)"; Search = "wo wolof wolof" },
        @{ Value = "xh"; Label = "xh (Xhosa)"; Search = "xh xhosa xhosa" },
        @{ Value = "yi"; Label = "yi (Yidis)"; Search = "yi yidis yiddish" },
        @{ Value = "yo"; Label = "yo (Yoruba)"; Search = "yo yoruba yoruba" },
        @{ Value = "yua"; Label = "yua (Yucatec Maya)"; Search = "yua yucatec maya yucatec maya" },
        @{ Value = "yue"; Label = "yue (Cantonese)"; Search = "yue cantonese cantonese" },
        @{ Value = "zap"; Label = "zap (Zapotec)"; Search = "zap zapotec zapotec" },
        @{ Value = "zh-TW"; Label = "zh-TW (Chino (Tradicional))"; Search = "zh-tw chino (tradicional) chinese (traditional)" },
        @{ Value = "zu"; Label = "zu (Zulú)"; Search = "zu zulú zulu" }
    )
    $global:VorkTranslateLanguages = $raw
    return $raw
}


function Invoke-PillarTranslate {
    param([string[]]$ArgsList)

    $to = "en"
    $text = ""

    if ($ArgsList -and $ArgsList.Length -gt 0) {
        $to = $ArgsList[0]
        if ($ArgsList.Length -gt 1) {
            $text = ($ArgsList[1..($ArgsList.Length - 1)]) -join " "
        }
    }

    if (-not $text) {
        Write-VorkSectionHeader -Title "Traducción" -Subtitle "Texto a traducir · más de 200 idiomas" -RightText "vork · translate"
        $textInput = Read-VorkInput -Prompt "  ${Coral}${Bold}$([char]0x203A)${Reset} "
        if (-not $textInput -or -not $textInput.Trim()) {
            Write-VorkStatusLine -Kind warn -Text "Traducción cancelada."
            Write-Host ""
            return
        }
        $text = $textInput.Trim()

        $langOptions = Get-VorkTranslateLanguages
        $chosenLang = Select-InteractiveOption -PromptTitle "Idioma destino" -Subtitle "traducción neuronal · +200 idiomas" -Options $langOptions -DefaultIndex 0 -Searchable
        if (-not $chosenLang) {
            Write-VorkStatusLine -Kind warn -Text "Traducción cancelada."
            Write-Host ""
            return
        }
        $to = $chosenLang
    }

    Write-VorkSectionHeader -Title "Procesando traducción" -RightText "vork · translate"
    Write-VorkInfoRow -Label "Destino" -Value $to -ValueColor $Yellow
    Write-VorkInfoRow -Label "Entrada" -Value ('"' + $text + '"')
    Write-VorkSectionRule

    $body = @{ text = $text; targetLanguage = $to } | ConvertTo-Json
    try {
        $res = Invoke-RestMethod -Uri "$ApiBase/api/translate" -Method Post -Body $body -ContentType "application/json"
        Write-VorkStatusLine -Kind ok -Text "Traducción completada"
        Write-VorkInfoRow -Label "Salida" -Value $res.translatedText -ValueColor $White

        $outFile = "traduccion.txt"
        $resolvedOut = Join-Path (Get-Location) $outFile
        $dlUrl = if ($res.downloadUrl) {
            if ($res.downloadUrl.StartsWith("http")) { $res.downloadUrl } else { "$ApiBase$($res.downloadUrl)" }
        } else {
            "$ApiBase/api/translate/download?translatedText=$([System.Uri]::EscapeDataString($res.translatedText))"
        }

        $outputMode = Select-VorkTextOutputAction -PromptTitle "Entrega del texto"
        if (-not $outputMode) {
            Write-VorkStatusLine -Kind warn -Text "Entrega cancelada."
            Write-VorkSectionRule
            Write-Host ""
            return
        }

        $hasLocal = $outputMode -in @("local", "all")
        $hasDownload = $outputMode -in @("download", "all")

        if ($hasLocal) {
            [System.IO.File]::WriteAllText($resolvedOut, $res.translatedText, [System.Text.Encoding]::UTF8)
            $resolvedPath = (Resolve-Path $outFile).Path
            Write-VorkInfoRow -Label "Guardado" -Value $resolvedPath -ValueColor $Green
        }

        if ($hasDownload) {
            Write-VorkInfoRow -Label "Enlace" -Value $dlUrl -ValueColor $Cyan
        }

        Write-VorkSectionRule
        Send-VorkNotification -Title "Vork Traductor" -Message "Traducción completada con éxito."
    } catch {
        Write-VorkStatusLine -Kind error -Text "Error al traducir" -Detail $_.Exception.Message
        Write-VorkSectionRule
    }
    Write-Host ""
}
