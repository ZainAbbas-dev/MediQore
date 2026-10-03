// Building blocks for synthetic people and places (LI-10). Every combination is
// made up; none of it describes a real patient.

// Districts of the Potohar region with approximate centres, so maps look
// realistic. Areas and households are scattered at random around them.
const DISTRICTS = [
  { name: 'Rawalpindi', code: 'RWP', lat: 33.6, lng: 73.05 },
  { name: 'Attock', code: 'ATK', lat: 33.77, lng: 72.36 },
  { name: 'Chakwal', code: 'CKW', lat: 32.93, lng: 72.86 },
  { name: 'Jhelum', code: 'JLM', lat: 32.94, lng: 73.73 },
];

const WOMEN = [
  'Ayesha', 'Fatima', 'Zainab', 'Maryam', 'Sana', 'Rabia', 'Nadia', 'Saima', 'Shazia', 'Bushra',
  'Asma', 'Farah', 'Hina', 'Iqra', 'Kiran', 'Mehwish', 'Nazia', 'Rukhsana', 'Samina', 'Shabana',
  'Sobia', 'Tahira', 'Uzma', 'Yasmin', 'Amna', 'Noreen', 'Parveen', 'Razia', 'Sadia', 'Sumaira',
];

const MEN = [
  'Ahmed', 'Ali', 'Bilal', 'Faisal', 'Hamza', 'Imran', 'Junaid', 'Kashif', 'Asif', 'Nadeem',
  'Omar', 'Qasim', 'Rashid', 'Saad', 'Tariq', 'Usman', 'Waqas', 'Yasir', 'Zubair', 'Arshad',
  'Javed', 'Khalid', 'Sajid', 'Shahid',
];

const FAMILY = ['Khan', 'Ahmed', 'Hussain', 'Malik', 'Butt', 'Qureshi', 'Raja', 'Chaudhry', 'Abbasi', 'Awan', 'Bhatti', 'Mughal', 'Shah', 'Iqbal'];

const VILLAGE_FIRST = ['Dhok', 'Chak', 'Mohra', 'Kot', 'Pind', 'Banda', 'Basti', 'Thatti'];
const VILLAGE_SECOND = ['Syedan', 'Gujran', 'Jattan', 'Kalan', 'Khurd', 'Sharif', 'Nau', 'Sultan', 'Mir', 'Ilyas'];

const KNOWN_CONDITIONS = ['Hypertension', 'Diabetes', 'Anaemia', 'Thyroid disorder', 'Asthma'];

module.exports = { DISTRICTS, WOMEN, MEN, FAMILY, VILLAGE_FIRST, VILLAGE_SECOND, KNOWN_CONDITIONS };
