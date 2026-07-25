import '../../features/transactions/presentation/category_picker_sheet.dart';

/// Fully-offline merchant → category matcher. Maps a merchant name to a real
/// entry in the app's category catalog (so the icon, colour and name all line
/// up) without any network/AI call. Used both by the Gmail import and by the
/// New Transaction screen to auto-fill the category from the payee.
///
/// To tune categorisation, edit [_rules] — each entry is `'keyword':
/// 'categoryId'`, where the id must exist in [allCategories] or
/// [incomeCategories] (see category_picker_sheet.dart). Keywords are matched
/// case-insensitively as substrings, and the FIRST match wins, so the category
/// order below (food → shopping → … → salary) sets the priority.
class CategoryClassifier {
  const CategoryClassifier._();

  static const Map<String, String> _rules = {
    // ── Food & dining ─────────────────────────────────────────
    // ── Food & Dining ─────────────────────────────────────────────────────────

// Delivery apps
'swiggy': 'food_drink',
'zomato': 'food_drink',
'dunzo': 'food_drink',
'blinkit': 'food_drink',      // quick commerce, often food
'zepto': 'food_drink',

// Fast food chains
'dominos': 'food_drink',
'pizza': 'food_drink',
'kfc': 'food_drink',
'mcdonald': 'food_drink',
'burger': 'food_drink',
'subway': 'food_drink',
'burger king': 'food_drink',
'pizza hut': 'food_drink',
'taco bell': 'food_drink',
'wendy': 'food_drink',
'hardee': 'food_drink',

// Cafes & beverages
'cafe': 'food_drink',
'coffee': 'food_drink',
'starbucks': 'food_drink',
'ccd': 'food_drink',          // Cafe Coffee Day
'barista': 'food_drink',
'chai': 'food_drink',
'tea': 'food_drink',
'juice': 'food_drink',
'smoothie': 'food_drink',
'milkshake': 'food_drink',
'lassi': 'food_drink',

// Indian restaurants & cuisine
'restaurant': 'food_drink',
'biryani': 'food_drink',
'dhaba': 'food_drink',
'eatery': 'food_drink',
'dining': 'food_drink',
'kitchen': 'food_drink',
'food': 'food_drink',
'thali': 'food_drink',
'dosa': 'food_drink',
'idli': 'food_drink',
'paratha': 'food_drink',
'tandoor': 'food_drink',
'tikka': 'food_drink',
'curry': 'food_drink',
'halal': 'food_drink',
'tiffin': 'food_drink',
'mess': 'food_drink',   
       // hostel/office mess

// Bakery & sweets
'bakery': 'food_drink',
'baker': 'food_drink',
'sweet': 'food_drink',
'mithai': 'food_drink',
'halwai': 'food_drink',
'cake': 'food_drink',
'pastry': 'food_drink',
'biscuit': 'food_drink',
'chocolate': 'food_drink',
'dessert': 'food_drink',
'ice cream': 'food_drink',
'gelato': 'food_drink',
'kwality': 'food_drink',      // Kwality Walls
'amul': 'food_drink',

// Hotels & dining (note: 'hotel' also means restaurant in India)
'hotel': 'food_drink',
'hotal': 'food_drink',
'wines': 'food_drink',
'bar': 'food_drink',
'pub': 'food_drink',
'brewery': 'food_drink',
'lounge': 'food_drink',
'canteen': 'food_drink',
'buffet': 'food_drink',

// Popular Indian chains
'barbeque nation': 'food_drink',
'bbq': 'food_drink',
'haldiram': 'food_drink',
'bikaner': 'food_drink',
'saravana': 'food_drink',
'udupi': 'food_drink',
'naturals': 'food_drink',     // Natural Ice Cream
'baskin': 'food_drink',       // Baskin Robbins
'wow momo': 'food_drink',
'momo': 'food_drink',
'roll': 'food_drink',         // Faasos / roll joints
'faasos': 'food_drink',
'rebel foods': 'food_drink',
'freshmenu': 'food_drink',
'box8': 'food_drink',
'eat fit': 'food_drink',
'eatfit': 'food_drink',
'oven story': 'food_drink',
'bawarchi': 'food_drink',

// Grocery (if you want it under food, else move to shopping)
'grocery': 'food_drink',
'supermarket': 'food_drink',
'fruits': 'food_drink',
'vegetables': 'food_drink',
'meat': 'food_drink',
'fish': 'food_drink',
'chicken': 'food_drink',
'milk': 'food_drink',
'dairy': 'food_drink',
'eggs': 'food_drink', 
    // ── Shopping ──────────────────────────────────────────────

    // ── Shopping ──────────────────────────────────────────────────────────────

// Major e-commerce platforms
'amazon': 'shopping',
'flipkart': 'shopping',
'ekart': 'shopping',          // Flipkart delivery arm
'meesho': 'shopping',
'snapdeal': 'shopping',
'shopclues': 'shopping',
'indiamart': 'shopping',
'glowroad': 'shopping',
'mart': 'shopping',

// Fashion & clothing
'myntra': 'shopping',
'ajio': 'shopping',
'nykaa fashion': 'shopping',
'westside': 'shopping',
'lifestyle': 'shopping',
'shoppers stop': 'shopping',
'trends': 'shopping',
'max fashion': 'shopping',
'h&m': 'shopping',
'zara': 'shopping',
'uniqlo': 'shopping',
'gap': 'shopping',
'levis': 'shopping',
'pepe jeans': 'shopping',
'wrangler': 'shopping',
'arrow': 'shopping',
'peter england': 'shopping',
'van heusen': 'shopping',
'allen solly': 'shopping',
'raymond': 'shopping',
'manyavar': 'shopping',
'fabindia': 'shopping',
'biba': 'shopping',
'w for woman': 'shopping',
'global desi': 'shopping',
'aurelia': 'shopping',
'pantaloons': 'shopping',
'reliance trends': 'shopping',

// Beauty & personal care
'nykaa': 'shopping',
'purplle': 'shopping',
'mamaearth': 'shopping',
'wow skin': 'shopping',
'forest essentials': 'shopping',
'biotique': 'shopping',
'lakme': 'shopping',
'loreal': 'shopping',
'gillette': 'shopping',
'salon': 'shopping',
'parlour': 'shopping',
'parlor': 'shopping',
'spa': 'shopping',

// Electronics & gadgets
'croma': 'shopping',
'reliance digital': 'shopping',
'vijay sales': 'shopping',
'poorvika': 'shopping',
'sangeetha': 'shopping',
'oneplus': 'shopping',
'samsung': 'shopping',
'apple store': 'shopping',
'mi store': 'shopping',
'boat': 'shopping',
'noise': 'shopping',           // Noise smartwatches

// Grocery & supermarkets
'dmart': 'shopping',
'bigbasket': 'shopping',
'reliance fresh': 'shopping',
'reliance smart': 'shopping',
'more supermarket': 'shopping',
'star bazaar': 'shopping',
'spencer': 'shopping',
'nature basket': 'shopping',
'lulu': 'shopping',
'easyday': 'shopping',
'spar': 'shopping',
'jiomart': 'shopping',           // if not under food
'swiggy instamart': 'shopping',

// Home & furniture
'ikea': 'shopping',
'pepperfry': 'shopping',
'urban ladder': 'shopping',
'hometown': 'shopping',
'godrej interio': 'shopping',
'nilkamal': 'shopping',
'fabfurnish': 'shopping',

// Hardware & tools
'hardware': 'shopping',
'toolbox': 'shopping',
'stanley': 'shopping',

// Sports & outdoors
'decathlon': 'shopping',
'nike': 'shopping',
'adidas': 'shopping',
'puma': 'shopping',
'reebok': 'shopping',
'skechers': 'shopping',
'bata': 'shopping',
'metro shoes': 'shopping',
'khadim': 'shopping',
'liberty shoes': 'shopping',

// Books & stationery (if not under education)
'crossword': 'shopping',
'landmark': 'shopping',
'flipkart books': 'shopping',
'amazon books': 'shopping',

// Gifting & miscellaneous
'ferns': 'shopping',           // Ferns N Petals
'fnp': 'shopping',
'archies': 'shopping',
'hallmark': 'shopping',
'gift': 'shopping',
'wrapping': 'shopping',
'igp': 'shopping',             // IndianGiftsPortal

// Watches & jewellery
'tanishq': 'shopping',
'kalyan jewellers': 'shopping',
'malabar gold': 'shopping',
'caratlane': 'shopping',
'bluestone': 'shopping',
'titan': 'shopping',
'fastrack': 'shopping',
'casio': 'shopping',

// Optical
'lenskart': 'shopping',
'titan eye': 'shopping',
'specsmakers': 'shopping',
'coolwinks': 'shopping',
    
    // ── Travel (outstation / holidays) ────────────────────────
    'flight': 'travel',
    'airline': 'travel',
    'air india': 'travel',
    'indigo': 'travel',
    'spicejet': 'travel',
    'vistara': 'travel',
    'akasa': 'travel',
    'go first': 'travel',
    'airport': 'travel',
    'irctc': 'travel', // moved from transport (outstation intent)
    'railways': 'travel', // moved from transport
    'train': 'travel',
    'railyatri': 'travel',
    'confirmtkt': 'travel',
    'redbus': 'travel', // outstation bus booking
    'abhibus': 'travel',
    'makemytrip': 'travel', // moved from transport
    'goibibo': 'travel',
    'cleartrip': 'travel',
    'easemytrip': 'travel',
    'yatra': 'travel',
    'paytm travel': 'travel',
    'oyo': 'travel',
    'treebo': 'travel',
    'fabhotels': 'travel',
    'zostel': 'travel',
    'airbnb': 'travel',
    'stayzy': 'travel',
    'resort': 'travel',
    'lodge': 'travel',
    'hostel': 'travel',
    'tour': 'travel',
    'holiday': 'travel',
    'visa': 'travel',
    // ── Transport ─────────────────────────────────────────────
    // 'uber': 'transport',
    // 'ola': 'transport',
    // 'rapido': 'transport',
    // 'irctc': 'transport',
    // 'railways': 'transport',
    // 'metro': 'transport',
    // 'petrol': 'transport',
    // 'fuel': 'transport',
    // 'fillin': 'transport', // "...FILLIN[G]" fuel pumps (SBI truncates to 20)
    // 'petroleum': 'transport',
    // 'filling station': 'transport',
    // 'hp': 'transport',
    // 'indian oil': 'transport',
    // 'bpcl': 'transport',
    // 'shell': 'transport',
    // 'auto': 'transport',
    // 'cab': 'transport',
    // 'bus': 'transport',
    // 'toll': 'transport',
    // 'makemytrip': 'transport',

    // ── Transport (local/daily commute) ───────────────────────────────────────
'uber': 'transport',
'ola': 'transport',
'rapido': 'transport',
'meru': 'transport',
'indrive': 'transport',
'namma yatri': 'transport',
'jugnu': 'transport',
'taxi': 'transport',
'cab': 'transport',
'auto': 'transport',
'rickshaw': 'transport',
'metro': 'transport',
'dmrc': 'transport',
'bmrcl': 'transport',
'hmrl': 'transport',
'cmrl': 'transport',
'shuttle': 'transport',
'bus': 'transport',
'apsrtc': 'transport',
'ksrtc': 'transport',
'tsrtc': 'transport',
'msrtc': 'transport',
'upsrtc': 'transport',
'gsrtc': 'transport',
'petrol': 'transport',
'fuel': 'transport',
'diesel': 'transport',
'fillin': 'transport',
'petroleum': 'transport',
'filling station': 'transport',
'hp': 'transport',
'hpcl': 'transport',
'indian oil': 'transport',
'iocl': 'transport',
'bpcl': 'transport',
'shell': 'transport',
'nayara': 'transport',
'cng': 'transport',
'toll': 'transport',
'nhai': 'transport',
'fasttag': 'transport',   // move from utilities
'fastag': 'transport',    // move from utilities
'parking': 'transport',
'ather': 'transport',
'bounce': 'transport',
'yulu': 'transport',
'vogo': 'transport',
'ev charge': 'transport',
'charging station': 'transport',



    // ── Utilities ─────────────────────────────────────────────────────────────

// Mobile operators
'airtel': 'utilities',
'jio': 'utilities',
'bsnl': 'utilities',
'vodafone': 'utilities',
'vi ': 'utilities',               // Vi (Vodafone Idea) — trailing space avoids false match
'idea': 'utilities',
'mtnl': 'utilities',
'recharge': 'utilities',
'prepaid': 'utilities',
'postpaid': 'utilities',
'mobile bill': 'utilities',
'phone bill': 'utilities',

// Broadband & internet
'broadband': 'utilities',
'wifi': 'utilities',
'internet': 'utilities',
'fiber': 'utilities',
'fibre': 'utilities',
'airtel fiber': 'utilities',
'jio fiber': 'utilities',
'act fibernet': 'utilities',
'act broadband': 'utilities',
'hathway': 'utilities',
'tikona': 'utilities',
'you broadband': 'utilities',
'excitel': 'utilities',
'den networks': 'utilities',
'tata play fiber': 'utilities',
'sify': 'utilities',

// DTH & cable TV
'tata sky': 'utilities',
'tata play': 'utilities',
'dish tv': 'utilities',
'd2h': 'utilities',
'videocon d2h': 'utilities',
'sun direct': 'utilities',
'airtel dth': 'utilities',
'dth': 'utilities',
'cable tv': 'utilities',
'set top': 'utilities',

// Electricity
'electricity': 'utilities',
'electric bill': 'utilities',
'power bill': 'utilities',
'bescom': 'utilities',           // Bangalore
'msedcl': 'utilities',          // Maharashtra
'tsspdcl': 'utilities',         // Telangana south
'tsnpdcl': 'utilities',         // Telangana north
'apspdcl': 'utilities',         // Andhra south
'apepdcl': 'utilities',         // Andhra east
'tneb': 'utilities',            // Tamil Nadu
'kseb': 'utilities',            // Kerala
'bses': 'utilities',            // Delhi
'tpddl': 'utilities',           // Delhi
'cesc': 'utilities',            // Kolkata
'wbsedcl': 'utilities',         // West Bengal
'torrent power': 'utilities',   // Gujarat
'adani electricity': 'utilities',
'adani power': 'utilities',
'reliance energy': 'utilities',
'tata power': 'utilities',

// Water & sewage
'water': 'utilities',
'water bill': 'utilities',
'bwssb': 'utilities',           // Bangalore water
'hmws': 'utilities',            // Hyderabad water
'mcgm water': 'utilities',      // Mumbai water
'sewage': 'utilities',

// Gas (piped & cylinder)
'gas': 'utilities',
'piped gas': 'utilities',
'png': 'utilities',             // Piped Natural Gas
'lpg': 'utilities',
'cylinder': 'utilities',
'indane': 'utilities',          // Indian Oil LPG
'hp gas': 'utilities',          // HPCL LPG
'bharat gas': 'utilities',      // BPCL LPG
'mahanagar gas': 'utilities',   // Mumbai PNG
'adani gas': 'utilities',
'gujarat gas': 'utilities',
'igl': 'utilities',             // Indraprastha Gas Delhi

// Society & maintenance
'maintenance': 'utilities',
'society': 'utilities',
'apartment': 'utilities',
'housing society': 'utilities',
'mygate': 'utilities',
'nobroker': 'utilities',
'apnacomplex': 'utilities',

// Municipal & government bills
'municipal': 'utilities',
'property tax': 'utilities',
'house tax': 'utilities',
'bbmp': 'utilities',            // Bangalore municipal
'ghmc': 'utilities',            // Hyderabad municipal
'mcgm': 'utilities',            // Mumbai municipal
'ndmc': 'utilities',            // Delhi municipal

// Bill payment platforms
'bbps': 'utilities',
'billdesk': 'utilities',
'paytm bill': 'utilities',
'phonepe bill': 'utilities',
'bill payment': 'utilities',
'utility': 'utilities',


    // ── Entertainment ─────────────────────────────────────────────────────────

// Video streaming
'netflix': 'entertainment',
'amazon prime': 'entertainment',  // must be before 'amazon'
'hotstar': 'entertainment',
'disney': 'entertainment',
'disney+': 'entertainment',
'zee5': 'entertainment',
'sonyliv': 'entertainment',
'sony liv': 'entertainment',
'voot': 'entertainment',
'alt balaji': 'entertainment',
'altbalaji': 'entertainment',
'mx player': 'entertainment',
'mxplayer': 'entertainment',
'aha': 'entertainment',           // Telugu OTT
'sun nxt': 'entertainment',       // Tamil OTT
'sunnxt': 'entertainment',
'hoichoi': 'entertainment',       // Bengali OTT
'manorama max': 'entertainment',  // Malayalam OTT
'stage': 'entertainment',         // regional OTT
'jiocinema': 'entertainment',
'jio cinema': 'entertainment',
'youtube': 'entertainment',
'youtube premium': 'entertainment',
'zee': 'entertainment',

// Music streaming
'spotify': 'entertainment',
'jiosaavn': 'entertainment',
'jio saavn': 'entertainment',
'gaana': 'entertainment',
'wynk': 'entertainment',          // Airtel Wynk
'hungama': 'entertainment',
'apple music': 'entertainment',
'amazon music': 'entertainment',
'itunes': 'entertainment',

// App stores & games
'app store': 'entertainment',     // must be before 'apple'
'google play': 'entertainment',
'apple': 'entertainment',
'steam': 'entertainment',
'epic games': 'entertainment',
'playstation': 'entertainment',
'xbox': 'entertainment',
'nintendo': 'entertainment',
'garena': 'entertainment',        // Free Fire
'krafton': 'entertainment',       // BGMI
'activision': 'entertainment',
'supercell': 'entertainment',     // Clash of Clans
'dream11': 'entertainment',
'my11circle': 'entertainment',
'mobile premier': 'entertainment',// MPL
'mpl': 'entertainment',
'winzo': 'entertainment',
'games': 'entertainment',
'gaming': 'entertainment',

// Movies & cinema
'bookmyshow': 'entertainment',
'pvr': 'entertainment',
'inox': 'entertainment',
'cinepolis': 'entertainment',
'carnival cinema': 'entertainment',
'miraj cinema': 'entertainment',
'movie': 'entertainment',
'cinema': 'entertainment',
'theatre': 'entertainment',
'multiplex': 'entertainment',
'ticket': 'entertainment',        // use carefully — may conflict with support tickets

// Live events & shows
'paytm insider': 'entertainment',
'insider': 'entertainment',
'district app': 'entertainment',
'livelaw': 'entertainment',
'zomato live': 'entertainment',
'concert': 'entertainment',
'comedy': 'entertainment',
'standup': 'entertainment',
'event': 'entertainment',
'show': 'entertainment',
'exhibition': 'entertainment',
'amusement': 'entertainment',
'theme park': 'entertainment',
'wonderla': 'entertainment',
'essel world': 'entertainment',

// Sports & recreation
'fantasy': 'entertainment',
'ipl': 'entertainment',
'bcci': 'entertainment',
'cricket': 'entertainment',
'sports ticket': 'entertainment',

// Podcasts & audio
'pocket casts': 'entertainment',
'pocketcasts': 'entertainment',
'castbox': 'entertainment',
'kuku fm': 'entertainment',
'kukufm': 'entertainment',
'audible': 'entertainment',
'storytel': 'entertainment',

// Books & reading (if not under education)
'kindle': 'entertainment',
'scribd': 'entertainment',
'juggernaut': 'entertainment',    // Indian ebook platform

// Misc digital entertainment
'canva': 'entertainment',         // only if personal use
'adobe': 'entertainment',         // only if personal use
'twitch': 'entertainment',
'loco': 'entertainment',          // Indian game streaming
'rooter': 'entertainment',
    // ── Health ────────────────────────────────────────────────────────────────

// Pharmacy chains
'apollo pharmacy': 'health',
'apollo': 'health',
'medplus': 'health',
'netmeds': 'health',
'1mg': 'health',
'pharmeasy': 'health',
'tata 1mg': 'health',
'saveon': 'health',
'wellness forever': 'health',
'guardian pharmacy': 'health',
'frank ross': 'health',
'medicine shoppe': 'health',
'pharma': 'health',
'pharmacy': 'health',
'chemist': 'health',
'druggist': 'health',
'medical store': 'health',
'medical shop': 'health',
'medical': 'health',

// Hospitals & clinics
'hospital': 'health',
'clinic': 'health',
'nursing home': 'health',
'nursing': 'health',
'multispeciality': 'health',
'maternity': 'health',
'fortis': 'health',
'manipal': 'health',
'aster': 'health',
'max hospital': 'health',
'narayana': 'health',
'columbia asia': 'health',
'cloudnine': 'health',
'care hospital': 'health',
'rainbow hospital': 'health',
'yashoda': 'health',
'kims': 'health',
'aiims': 'health',
'medanta': 'health',
'lilavati': 'health',
'kokilaben': 'health',
'breach candy': 'health',
'jaslok': 'health',

// Doctors & consultations
'doctor': 'health',
'dr ': 'health',              // "Dr Sharma clinic"
'physician': 'health',
'surgeon': 'health',
'specialist': 'health',
'gynaecologist': 'health',
'gynecologist': 'health',
'paediatrician': 'health',
'pediatrician': 'health',
'dermatologist': 'health',
'dentist': 'health',
'dental': 'health',
'orthodontist': 'health',
'ophthalmologist': 'health',
'optometrist': 'health',
'physiotherapist': 'health',
'physiotherapy': 'health',
'orthopedic': 'health',
'cardiologist': 'health',
'neurologist': 'health',
'psychiatrist': 'health',
'psychologist': 'health',
'counselling': 'health',
'therapist': 'health',

// Diagnostics & labs
'lab': 'health',
'laboratory': 'health',
'diagnostic': 'health',
'pathology': 'health',
'radiology': 'health',
'scan': 'health',
'xray': 'health',
'x-ray': 'health',
'mri': 'health',
'ultrasound': 'health',
'blood test': 'health',
'thyrocare': 'health',
'dr lal': 'health',
'lal path': 'health',
'metropolis': 'health',
'srl diagnostics': 'health',
'vijaya diagnostics': 'health',
'healthians': 'health',

// Online health platforms
'practo': 'health',
'docon': 'health',
'mfine': 'health',
'doc prime': 'health',
'docprime': 'health',
'ndhm': 'health',
'healthkart': 'health',
'cult fit': 'health',
'cultfit': 'health',
'cure fit': 'health',
'curefit': 'health',

// Fitness & wellness
'gym': 'health',
'fitness': 'health',
'yoga': 'health',
'pilates': 'health',
'zumba': 'health',
'crossfit': 'health',
'gold gym': 'health',
'anytime fitness': 'health',
'snap fitness': 'health',
'talwalkars': 'health',
'wellness': 'health',
'ayurveda': 'health',
'homeopathy': 'health',
'naturopathy': 'health',

// Medical equipment & supplies
'surgical': 'health',
'orthopaedic': 'health',
'wheelchair': 'health',
'glucometer': 'health',
'bp monitor': 'health',
'oximeter': 'health',
'nebulizer': 'health',
'hearing aid': 'health',

// Mental health
'meditation': 'health',
'headspace': 'health',
'calm app': 'health',
'innerhour': 'health',
'wysa': 'health',
'vandrevala': 'health',
'nimhans': 'health',

// General health terms
'health': 'health',
'medicine': 'health',
'tablet': 'health',
'capsule': 'health',
'injection': 'health',
'vaccine': 'health',
'vaccination': 'health',
'immunisation': 'health',
'immunization': 'health',
'ambulance': 'health',
'emergency': 'health',
    

// ── Education ─────────────────────────────────────────────────────────────

// Online learning platforms (global)
'udemy': 'education',
'coursera': 'education',
'skillshare': 'education',
'linkedin learning': 'education',
'pluralsight': 'education',
'edx': 'education',
'khan academy': 'education',
'codecademy': 'education',
'brilliant': 'education',
'masterclass': 'education',
'simplilearn': 'education',
'great learning': 'education',
'upgrad': 'education',
'emeritus': 'education',

// Online learning platforms (Indian)
'byju': 'education',
'unacademy': 'education',
'vedantu': 'education',
'toppr': 'education',
'meritnation': 'education',
'doubtnut': 'education',
'extramarks': 'education',
'physicswallah': 'education',
'pw app': 'education',
'testbook': 'education',
'gradeup': 'education',
'adda247': 'education',
'oliveboard': 'education',
'prepladder': 'education',       // medical entrance
'drills': 'education',
'embibe': 'education',
'classplus': 'education',
'teachmint': 'education',

// Schools & institutions
'school': 'education',
'college': 'education',
'university': 'education',
'institute': 'education',
'institution': 'education',
'academy': 'education',
'vidyalaya': 'education',
'vidhyalaya': 'education',
'gurukul': 'education',
'convent': 'education',
'matriculation': 'education',
'cbse': 'education',
'icse': 'education',
'iit': 'education',
'nit': 'education',
'iim': 'education',
'bits pilani': 'education',

// Fees & payments
'tuition': 'education',
'tuition fee': 'education',
'coaching': 'education',
'coaching fee': 'education',
'course fee': 'education',
'admission fee': 'education',
'exam fee': 'education',
'registration fee': 'education',
'hostel fee': 'education',
'semester fee': 'education',
'term fee': 'education',
'annual fee': 'education',       // watch out — conflicts with credit card annual fee
'library fee': 'education',
'lab fee': 'education',

// Books & stationery
'book': 'education',
'stationery': 'education',
'notebook': 'education',
'textbook': 'education',
'workbook': 'education',
'pen ': 'education',             // trailing space avoids "peninsula", "pending"
'pencil': 'education',
'compass box': 'education',
'geometry': 'education',
'calculator': 'education',
// 'crossword': 'education',        // bookstore
// 'landmark': 'education',         // bookstore
'sapna book': 'education',       // Sapna Book House
'higginbotham': 'education',     // South India bookstore
'word worth': 'education',

// Competitive exam prep
'upsc': 'education',
'gate': 'education',
'cat prep': 'education',
'gmat': 'education',
'gre': 'education',
'ielts': 'education',
'toefl': 'education',
'neet': 'education',
'jee': 'education',
'ssc': 'education',
'ibps': 'education',
'rbi grade': 'education',

// Certifications & professional courses
'certification': 'education',
'certificate': 'education',
'workshop': 'education',
'seminar': 'education',
'training': 'education',
'bootcamp': 'education',
'boot camp': 'education',
'internship': 'education',       // paid internship fee

// Stationery & supplies
'staples': 'education',
'classmate': 'education',        // Classmate notebooks
'camlin': 'education',
'faber castell': 'education',
'doms': 'education',
'natraj': 'education',
'reynolds': 'education',         // Reynolds pens
'pilot pen': 'education',
'lexi pen': 'education',





// ── Insurance ─────────────────────────────────────────────────────────────

// Life insurance
'lic': 'insurance',
'life insurance': 'insurance',
'hdfc life': 'insurance',
'icici pru': 'insurance',
'icici prudential': 'insurance',
'sbi life': 'insurance',
'max life': 'insurance',
'kotak life': 'insurance',
'kotak mahindra life': 'insurance',
'bajaj allianz life': 'insurance',
'tata aia': 'insurance',
'tata aia life': 'insurance',
'canara hsbc life': 'insurance',
'pnb metlife': 'insurance',
'pramerica life': 'insurance',
'bharti axa life': 'insurance',
'future generali life': 'insurance',
'ageas federal': 'insurance',
'edelweiss tokio': 'insurance',
'aviva life': 'insurance',
'aegon life': 'insurance',

// Health insurance
'star health': 'insurance',
'niva bupa': 'insurance',
'max bupa': 'insurance',
'care health': 'insurance',
'religare health': 'insurance',
'hdfc ergo health': 'insurance',
'aditya birla health': 'insurance',
'manipal cigna': 'insurance',
'manipalcigna': 'insurance',
'apollo munich': 'insurance',
'national insurance': 'insurance',
'united india insurance': 'insurance',
'oriental insurance': 'insurance',
'new india assurance': 'insurance',
'health insurance': 'insurance',
'mediclaim': 'insurance',
'medi claim': 'insurance',

// General & vehicle insurance
'bajaj allianz': 'insurance',
'icici lombard': 'insurance',
'hdfc ergo': 'insurance',
'tata aig': 'insurance',
'reliance general': 'insurance',
'cholamandalam': 'insurance',
'chola ms': 'insurance',
'royal sundaram': 'insurance',
'future generali': 'insurance',
'go digit': 'insurance',
'digit insurance': 'insurance',
'acko': 'insurance',
'iffco tokio': 'insurance',
'shriram general': 'insurance',
'universal sompo': 'insurance',
'magma hdi': 'insurance',

// Vehicle insurance specific
'motor insurance': 'insurance',
'car insurance': 'insurance',
'bike insurance': 'insurance',
'vehicle insurance': 'insurance',
'third party': 'insurance',
'comprehensive insurance': 'insurance',

// Term & policy related
'insurance': 'insurance',
'insure': 'insurance',
'policy': 'insurance',
'policybazaar': 'insurance',
'coverfox': 'insurance',
'turtlemint': 'insurance',
'renewbuy': 'insurance',
'easypolicy': 'insurance',
'premium': 'insurance',
'protect': 'insurance',
'protection plan': 'insurance',
'term plan': 'insurance',
'term insurance': 'insurance',
'endowment': 'insurance',
'ulip': 'insurance',
'money back': 'insurance',      // money back policy

// Travel insurance
'travel insurance': 'insurance',
'trip insurance': 'insurance',

// Home insurance
'home insurance': 'insurance',
'house insurance': 'insurance',
'property insurance': 'insurance',

// General terms
'renewal': 'insurance',
'renew policy': 'insurance',
'claim': 'insurance',
'sum assured': 'insurance',
'maturity': 'insurance',        // policy maturity
'nominee': 'insurance',




   


    // ── Finance ───────────────────────────────────────────────────────────────

// Loans & EMI
'emi': 'finance',
'loan': 'finance',
'home loan': 'finance',
'car loan': 'finance',
'personal loan': 'finance',
'education loan': 'finance',
'gold loan': 'finance',
'business loan': 'finance',
'loan emi': 'finance',
'emi payment': 'finance',
'loan repayment': 'finance',
'equated monthly': 'finance',
'bajaj finance': 'finance',
'bajaj finserv': 'finance',
'hdfc loan': 'finance',
'icici loan': 'finance',
'tata capital': 'finance',
'fullerton': 'finance',
'muthoot': 'finance',
'manappuram': 'finance',
'shriram finance': 'finance',
'l&t finance': 'finance',
'piramal finance': 'finance',
'aditya birla finance': 'finance',
'indiabulls': 'finance',
'iifl finance': 'finance',
'hero fincorp': 'finance',
'tvs credit': 'finance',

// Buy Now Pay Later
'bnpl': 'finance',
'buy now pay later': 'finance',
'lazypay': 'finance',
'simpl': 'finance',
'slice': 'finance',
'uni card': 'finance',
'unicard': 'finance',
'kissht': 'finance',
'zest money': 'finance',
'zestmoney': 'finance',
'paylater': 'finance',
'pay later': 'finance',
'kredit bee': 'finance',
'kreditbee': 'finance',
'money tap': 'finance',
'moneytap': 'finance',
'early salary': 'finance',
'earlysalary': 'finance',
'nira': 'finance',
'mpokket': 'finance',

// Mutual funds & SIP
'mutual fund': 'finance',
'sip': 'finance',
'lumpsum': 'finance',
'lump sum': 'finance',
'nav': 'finance',               // Net Asset Value
'mf purchase': 'finance',
'zerodha coin': 'finance',
'groww mutual': 'finance',
'paytm money': 'finance',
'kuvera': 'finance',
'scripbox': 'finance',
'etmoney': 'finance',
'et money': 'finance',
'icicidirect': 'finance',
'icici direct': 'finance',
'hdfc mutual': 'finance',
'sbi mutual': 'finance',
'nippon mutual': 'finance',
'axis mutual': 'finance',
'kotak mutual': 'finance',
'mirae asset': 'finance',
'franklin templeton': 'finance',
'dsp mutual': 'finance',
'sundaram mutual': 'finance',
'ppfas': 'finance',             // Parag Parikh

// Stock brokers & trading
'zerodha': 'finance',
'groww': 'finance',
'upstox': 'finance',
'angel broking': 'finance',
'angel one': 'finance',
'5paisa': 'finance',
'sharekhan': 'finance',
'motilal oswal': 'finance',
'kotak securities': 'finance',
'hdfc securities': 'finance',
'icici securities': 'finance',
'sbi securities': 'finance',
'edelweiss': 'finance',
'religare': 'finance',
'geojit': 'finance',
'mstock': 'finance',
'dhan': 'finance',
'fyers': 'finance',
'trading': 'finance',
'stocks': 'finance',
'equity': 'finance',
'demat': 'finance',
'brokerage': 'finance',
'nse': 'finance',
'bse': 'finance',
'sensex': 'finance',
'nifty': 'finance',

// Fixed deposits & savings
'fd': 'finance',
'fixed deposit': 'finance',
'recurring deposit': 'finance',
'rd': 'finance',
'deposit': 'finance',
'flexi deposit': 'finance',
'sweep deposit': 'finance',

// Retirement & provident fund
'nps': 'finance',
'national pension': 'finance',
'epf': 'finance',
'provident fund': 'finance',
'ppf': 'finance',
'public provident': 'finance',
'pension': 'finance',
'retirement': 'finance',
'atal pension': 'finance',
'nsdl': 'finance',
'protean': 'finance',           // NSDL rebranded

// Government savings schemes
'sukanya': 'finance',           // Sukanya Samriddhi
'kisan vikas': 'finance',
'kvp': 'finance',
'nsс': 'finance',               // National Savings Certificate
'sovereign gold': 'finance',    // Sovereign Gold Bond
'sgb': 'finance',
'post office': 'finance',       // Post office savings

// Investment terms
'investment': 'finance',
'invest': 'finance',
'portfolio': 'finance',
'dividend': 'finance',
// Interest *earned* is income (bank Int.Pd credits); must precede the generic
// 'interest' → finance below, since the first matching keyword wins.
'interest earned': 'interest',
'interest credit': 'interest',
'interest': 'finance',
'returns': 'finance',
'capital gain': 'finance',
'smallcase': 'finance',
'wint wealth': 'finance',
'grip invest': 'finance',
'p2p': 'finance',               // Peer to peer lending
'faircent': 'finance',
'lendingkart': 'finance',
'indifi': 'finance',

// Credit cards (payments)
'credit card bill': 'finance',
'card outstanding': 'finance',
'card payment': 'finance',
'card dues': 'finance',
'minimum due': 'finance',
'total due': 'finance',
'statement payment': 'finance',

// Forex & international
'forex': 'finance',
'foreign exchange': 'finance',
'wire transfer': 'finance',
'remittance': 'finance',
'western union': 'finance',
'wise': 'finance',
'niyo': 'finance',
'bookmyforex': 'finance',
'margadarsi': 'finance',
'kapil': 'finance',
'chit': 'finance',



// ── Salary / Income ───────────────────────────────────────────────────────

// Salary & payroll
'salary': 'salary',
'payroll': 'salary',
'sal credit': 'salary',
'salary credit': 'salary',
'monthly salary': 'salary',
'net salary': 'salary',
'gross salary': 'salary',
'take home': 'salary',
'pay credit': 'salary',
'wages': 'salary',
'monthly wages': 'salary',

// Payroll processors (companies use these to disburse salary)
'razorpayx': 'salary',          // Razorpay payroll
'razorpay x': 'salary',
'open payroll': 'salary',
'kredx': 'salary',
'keka': 'salary',               // Keka HR payroll
'greythr': 'salary',            // greytHR payroll
'darwinbox': 'salary',
'sumhr': 'salary',
'bamboohr': 'salary',
'zoho payroll': 'salary',
'quickbooks payroll': 'salary',
'netsuite': 'salary',
'adrenalin': 'salary',          // Adrenalin HR
'spine hr': 'salary',
'hrms': 'salary',

// Employer payments
'credit from employer': 'salary',
'employer': 'salary',
'company credit': 'salary',
'office credit': 'salary',
'neft from': 'salary',          // most salaries come via NEFT
'neft cr': 'salary',

// Bonus & incentives
'bonus': 'salary',
'performance bonus': 'salary',
'annual bonus': 'salary',
'joining bonus': 'salary',
'retention bonus': 'salary',
'incentive': 'salary',
'commission': 'salary',
'variable pay': 'salary',
'arrears': 'salary',
'salary arrears': 'salary',
'ex gratia': 'salary',
'gratuity': 'salary',

// Freelance & contract income
'stipend': 'salary',
'honorarium': 'salary',
'consultancy fee': 'salary',
'consulting fee': 'salary',
'freelance': 'salary',
'contract payment': 'salary',
'project payment': 'salary',
'invoice payment': 'salary',
'professional fee': 'salary',
'retainer': 'salary',

// Reimbursements
'reimbursement': 'salary',
'reimburse': 'salary',
'expense reimbursement': 'salary',
'travel reimbursement': 'salary',
'medical reimbursement': 'salary',
'conveyance': 'salary',
'conveyance allowance': 'salary',
'hra': 'salary',                // House Rent Allowance
'lta': 'salary',                // Leave Travel Allowance
'da credit': 'salary',          // Dearness Allowance

// Other income
'income': 'salary',
'earnings': 'salary',
'payout': 'salary',
'settlement': 'salary',         // full & final settlement
'fnf': 'salary',                // Full and Final
'full final': 'salary',
'leave encashment': 'salary',
'pension credit': 'salary',
'superannuation': 'salary',

// Government & PSU salary
'treasury': 'salary',
'government salary': 'salary',
'psu salary': 'salary',
'defence pay': 'salary',
'army pay': 'salary',
'pfms': 'salary',               // Public Financial Mgmt System
'sparsh': 'salary',             // Defence pension portal
'cppc': 'salary',               // Central Pension Processing Centre







   
  };

  /// Returns the catalog category for [merchant], or null when nothing matches
  /// (callers keep their existing default in that case).
  ///
  /// Pass [type] ('income' / 'expense') to reject a match from the wrong pool:
  /// keywords are loose substrings, so an expense can otherwise land on an
  /// income-only category (e.g. 'hra' matches "andHRA Pradesh" → Salary) and an
  /// income row on an expense-only one ('interest' → Finance). Such a match is
  /// discarded rather than replaced, so the caller's own fallback decides.
  static CategoryItem? classify(String? merchant, {String? type}) {
    final m = (merchant ?? '').toLowerCase().trim();
    if (m.isEmpty) return null;
    for (final entry in _rules.entries) {
      if (!m.contains(entry.key)) continue;
      final item = _itemForId(entry.value);
      if (type != null && !_poolFor(type).any((c) => c.id == item.id)) {
        return null; // matched, but not a category this direction can hold
      }
      return item;
    }
    return null;
  }

  static List<CategoryItem> _poolFor(String type) =>
      type == 'income' ? incomeCategories : allCategories;

  /// Returns just the category id for [merchant] ('other' when no match) —
  /// mirrors the keyword spec's getCategory().
  static String getCategory(String merchant) =>
      classify(merchant)?.id ?? 'other';

  static CategoryItem _itemForId(String id) {
    final pool = [...allCategories, ...incomeCategories];
    return pool.firstWhere(
      (c) => c.id == id,
      orElse: () => allCategories.firstWhere((c) => c.id == 'other'),
    );
  }
}
