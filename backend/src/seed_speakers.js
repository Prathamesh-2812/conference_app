import { pool } from './db.js';

const speakers = [
  {
    name: 'Dr. M. B. Agarwal',
    designation: 'Head of Hematology (MBBS, MD)',
    organization: 'Bombay Hospital, Mumbai',
    bio: 'Head of Hematology at Bombay Hospital, Mumbai and 2025 recipient of the ISHBT Lifetime Achievement Award.'
  },
  {
    name: 'Dr. Anita Mahadevan',
    designation: 'Head of Neuropathology (MBBS, MD)',
    organization: 'NIMHANS, Bangalore',
    bio: 'Head of Neuropathology at NIMHANS, Bangalore and Coordinator of the Human Brain Bank with 300+ publications.'
  },
  {
    name: 'Dr. Sangeeta Desai',
    designation: 'Former Head of Pathology (MBBS, MD)',
    organization: 'Tata Memorial Centre (TMC), Mumbai',
    bio: 'Former Head of Pathology at TMC, Mumbai who pioneered clinical molecular diagnostics and cancer biobanking in India.'
  },
  {
    name: 'Dr. Sumeet Gujral',
    designation: 'Professor (MBBS, MD)',
    organization: 'ACTREC-TMC, Mumbai',
    bio: 'Professor at ACTREC-TMC, Mumbai and author for the 5th edition WHO Classification of Hematolymphoid Tumors.'
  },
  {
    name: 'Dr. Mukta Ramadwar',
    designation: 'Professor (MD, FRCPath)',
    organization: 'Tata Memorial Hospital, Mumbai',
    bio: 'Professor at Tata Memorial Hospital, Mumbai and leading expert in paediatric and gastrointestinal oncopathology.'
  },
  {
    name: 'Dr. Kedar Deodhar',
    designation: 'Professor (MBBS, MD)',
    organization: 'Tata Memorial Hospital, Mumbai',
    bio: 'Professor at Tata Memorial Hospital, Mumbai, specializing in Gynecological and GI Pathology with 160+ publications.'
  },
  {
    name: 'Dr. Milind Bhide',
    designation: 'Laboratory Director (MBBS, MD)',
    organization: 'Mumbai',
    bio: 'Mumbai-based laboratory director and gold medalist specializing in endocrine immunoassay and LIS innovation.'
  },
  {
    name: 'Dr. Jay Mehta',
    designation: 'Chief (MBBS, MD)',
    organization: 'Neuberg Oncopath, Mumbai',
    bio: 'Chief of Neuberg Oncopath, Mumbai and the first pathologist to introduce PDL1 testing for lung cancer in India.'
  },
  {
    name: 'Dr. Anita Bhaduri',
    designation: 'Consultant Histopathologist & Former HOD (MBBS, MD)',
    organization: 'P.D. Hinduja Hospital & MRC, Mumbai',
    bio: 'Consultant Histopathologist and former HOD of Lab Medicine at P.D. Hinduja Hospital & MRC, Mumbai.'
  },
  {
    name: 'Dr. Asawari Patil',
    designation: 'Professor & Head and Neck Specialist (MBBS, MD, DABP)',
    organization: 'Tata Memorial Centre (TMC), Mumbai',
    bio: 'Head and Neck specialist, Professor at TMC, Mumbai and co-author of 5th Edition WHO Classification of Head and Neck Tumors.'
  },
  {
    name: 'Dr. Pravin P. Mahajan',
    designation: 'Senior Consultant (MBBS, MD)',
    organization: 'S. L. Raheja Hospital, Mumbai',
    bio: 'Senior Consultant at S. L. Raheja Hospital, Mumbai with 18+ years of expertise in advanced breast and lymphoma oncopathology.'
  },
  {
    name: 'Dr. Kishor Managoli',
    designation: 'Precision Medicine Strategist (MBBS, MD)',
    organization: 'Precision Medicine / Molecular AI',
    bio: 'Precision Medicine Strategist and 12-time U.S. patent holder bridging traditional pathology with molecular AI.'
  },
  {
    name: 'Col. Dr. Venkatesan Somasundaram',
    designation: 'Professor & Head - Dept. of Pathology (MBBS, MD, MNAMS, DM)',
    organization: 'AFMC, Pune',
    bio: 'Professor and Head-Department of Pathology at AFMC Pune, who received Dr. YM Bhende Gold Medal for standing first in Pune University.'
  },
  {
    name: 'Dr. Jaydeep Nilkanthrao Pol',
    designation: 'Chief Surgical Pathologist (MBBS, MD)',
    organization: 'MG Cancer Hospital, Miraj',
    bio: 'Chief Surgical Pathologist at MG Cancer Hospital, Miraj and winner of 2025 Excellence in Teaching Award.'
  },
  {
    name: 'Dr. Sachin Patil',
    designation: 'Pathologist (MBBS, MD)',
    organization: 'Shree Siddhivinayak Ganapati Cancer Hospital, Miraj',
    bio: 'Pathologist at Shree Siddhivinayak Ganapati Cancer Hospital, Miraj specializing in oncopathology.'
  },
  {
    name: 'Dr. Prashant Tembhare',
    designation: 'Professor in Hematopathology (MBBS, MD)',
    organization: 'ACTREC-TMC, Mumbai',
    bio: 'Professor in Hematopathology at ACTREC-TMC, Mumbai and author of 13 topics in 5th Edition WHO book for Hematolymphoid neoplasms.'
  },
  {
    name: 'Dr. Swapnil Rane',
    designation: 'Head of Digital Oncology (MBBS, MD, DNB, FRCPath)',
    organization: 'TMC-ACTREC, Mumbai',
    bio: 'Head of Digital Oncology at TMC-ACTREC, Mumbai and developer of India’s "Imaging Biobank for Cancer".'
  },
  {
    name: 'Dr. Shilpi Sahu',
    designation: 'Head of Pathology & Chairperson - BOS (MBBS, MD)',
    organization: 'MGM Medical College, Navi Mumbai',
    bio: 'Head of Pathology at MGM Medical College, Navi Mumbai, and Chairperson of the Board of Studies.'
  },
  {
    name: 'Dr. Sachin Kale',
    designation: 'Professor of Pathology (MBBS, MD)',
    organization: 'MGM Medical College, Navi Mumbai',
    bio: 'Professor of Pathology at MGM Medical College with over two decades of academic and research leadership.'
  },
  {
    name: 'Dr. Sagar Jaywantrao More',
    designation: 'Consultant Histopathologist (MBBS, MD, FRCPath)',
    organization: 'Sangli',
    bio: 'Consultant Histopathologist, Sangli and UK Royal College Fellow specializing in complex lymphoma and hepatobiliary pathology.'
  },
  {
    name: 'Dr. Rakhi Jagdale',
    designation: 'Head of Pathology (MBBS, MD)',
    organization: 'Shri Siddhivinayak Ganapati Cancer Hospital, Miraj',
    bio: 'Head of Pathology at Shri Siddhivinayak Ganapati Cancer Hospital, Miraj, with a special interest in Uropathology and Head & Neck Pathology.'
  },
  {
    name: 'Dr. Amruta Ashok Patil',
    designation: 'Consultant Histopathologist (MBBS, MD, DNB, FRCPath)',
    organization: 'Milton Keynes University Hospital, UK / Deesha Pathology Lab, Sangli',
    bio: 'International speaker, Consultant at Milton Keynes University Hospital, UK and Consultant Histopathologist at Deesha Pathology Lab, Sangli, specializing in gastrointestinal oncopathology.'
  },
  {
    name: 'Dr. Radhika Krishna Patil',
    designation: 'Director (MBBS, MD, FISN-ANIO, PDCC)',
    organization: 'Shri Balaji Kidney Care, Hyderabad',
    bio: 'Director of Shri Balaji Kidney Care, Hyderabad and winner of 2024 Dr. APJ Abdul Kalam Health Excellence Award.'
  },
  {
    name: 'Dr. Ashwini Mane Patil',
    designation: 'Consultant Histopathologist (MBBS, MD Pathology)',
    organization: 'Kolhapur Cancer Centre & Oncopathology Lab, Kolhapur',
    bio: 'Consultant Histopathologist at Kolhapur cancer centre & Oncopathology lab, Kolhapur. Special interest in Breast & Gynae pathology.'
  },
  {
    name: 'Dr. Kunal Sehgal',
    designation: 'Consultant Haemato-Pathologist & Flow Cytometrist, Director (MBBS, MD)',
    organization: 'Neuberg Sehgal Path Lab, Mumbai',
    bio: 'Consultant Haemato-Pathologist and Flow Cytometrist. Director, Neuberg Sehgal path lab, Mumbai. Fellowship in hematopathology, UICC-ICCRETT Fellow.'
  }
];

async function seed() {
  try {
    console.log('Seeding 25 speakers into conference_management database...');
    for (const s of speakers) {
      const [existing] = await pool.query('SELECT id FROM speakers WHERE name=? AND conference_id=1', [s.name]);
      if (existing.length > 0) {
        await pool.query(
          'UPDATE speakers SET designation=?, organization=?, bio=? WHERE id=?',
          [s.designation, s.organization, s.bio, existing[0].id]
        );
        console.log(`Updated: ${s.name}`);
      } else {
        await pool.query(
          'INSERT INTO speakers (conference_id, name, designation, organization, bio) VALUES (1, ?, ?, ?, ?)',
          [s.name, s.designation, s.organization, s.bio]
        );
        console.log(`Inserted: ${s.name}`);
      }
    }
    console.log('Successfully seeded all 25 speakers!');
  } catch (err) {
    console.error('Error seeding speakers:', err.message);
  } finally {
    process.exit(0);
  }
}

seed();
