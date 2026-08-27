USE conference_management;

-- Insert / Update all 25 distinguished conference speakers
INSERT INTO speakers (conference_id, name, designation, organization, bio) VALUES
(1, 'Dr. M. B. Agarwal', 'Head of Hematology (MBBS, MD)', 'Bombay Hospital, Mumbai', 'Head of Hematology at Bombay Hospital, Mumbai and 2025 recipient of the ISHBT Lifetime Achievement Award.'),
(1, 'Dr. Anita Mahadevan', 'Head of Neuropathology (MBBS, MD)', 'NIMHANS, Bangalore', 'Head of Neuropathology at NIMHANS, Bangalore and Coordinator of the Human Brain Bank with 300+ publications.'),
(1, 'Dr. Sangeeta Desai', 'Former Head of Pathology (MBBS, MD)', 'Tata Memorial Centre (TMC), Mumbai', 'Former Head of Pathology at TMC, Mumbai who pioneered clinical molecular diagnostics and cancer biobanking in India.'),
(1, 'Dr. Sumeet Gujral', 'Professor (MBBS, MD)', 'ACTREC-TMC, Mumbai', 'Professor at ACTREC-TMC, Mumbai and author for the 5th edition WHO Classification of Hematolymphoid Tumors.'),
(1, 'Dr. Mukta Ramadwar', 'Professor (MD, FRCPath)', 'Tata Memorial Hospital, Mumbai', 'Professor at Tata Memorial Hospital, Mumbai and leading expert in paediatric and gastrointestinal oncopathology.'),
(1, 'Dr. Kedar Deodhar', 'Professor (MBBS, MD)', 'Tata Memorial Hospital, Mumbai', 'Professor at Tata Memorial Hospital, Mumbai, specializing in Gynecological and GI Pathology with 160+ publications.'),
(1, 'Dr. Milind Bhide', 'Laboratory Director (MBBS, MD)', 'Mumbai', 'Mumbai-based laboratory director and gold medalist specializing in endocrine immunoassay and LIS innovation.'),
(1, 'Dr. Jay Mehta', 'Chief (MBBS, MD)', 'Neuberg Oncopath, Mumbai', 'Chief of Neuberg Oncopath, Mumbai and the first pathologist to introduce PDL1 testing for lung cancer in India.'),
(1, 'Dr. Anita Bhaduri', 'Consultant Histopathologist & Former HOD (MBBS, MD)', 'P.D. Hinduja Hospital & MRC, Mumbai', 'Consultant Histopathologist and former HOD of Lab Medicine at P.D. Hinduja Hospital & MRC, Mumbai.'),
(1, 'Dr. Asawari Patil', 'Professor & Head and Neck Specialist (MBBS, MD, DABP)', 'Tata Memorial Centre (TMC), Mumbai', 'Head and Neck specialist, Professor at TMC, Mumbai and co-author of 5th Edition WHO Classification of Head and Neck Tumors.'),
(1, 'Dr. Pravin P. Mahajan', 'Senior Consultant (MBBS, MD)', 'S. L. Raheja Hospital, Mumbai', 'Senior Consultant at S. L. Raheja Hospital, Mumbai with 18+ years of expertise in advanced breast and lymphoma oncopathology.'),
(1, 'Dr. Kishor Managoli', 'Precision Medicine Strategist (MBBS, MD)', 'Precision Medicine / Molecular AI', 'Precision Medicine Strategist and 12-time U.S. patent holder bridging traditional pathology with molecular AI.'),
(1, 'Col. Dr. Venkatesan Somasundaram', 'Professor & Head - Dept. of Pathology (MBBS, MD, MNAMS, DM)', 'AFMC, Pune', 'Professor and Head-Department of Pathology at AFMC Pune, who received Dr. YM Bhende Gold Medal for standing first in Pune University.'),
(1, 'Dr. Jaydeep Nilkanthrao Pol', 'Chief Surgical Pathologist (MBBS, MD)', 'MG Cancer Hospital, Miraj', 'Chief Surgical Pathologist at MG Cancer Hospital, Miraj and winner of 2025 Excellence in Teaching Award.'),
(1, 'Dr. Sachin Patil', 'Pathologist (MBBS, MD)', 'Shree Siddhivinayak Ganapati Cancer Hospital, Miraj', 'Pathologist at Shree Siddhivinayak Ganapati Cancer Hospital, Miraj specializing in oncopathology.'),
(1, 'Dr. Prashant Tembhare', 'Professor in Hematopathology (MBBS, MD)', 'ACTREC-TMC, Mumbai', 'Professor in Hematopathology at ACTREC-TMC, Mumbai and author of 13 topics in 5th Edition WHO book for Hematolymphoid neoplasms.'),
(1, 'Dr. Swapnil Rane', 'Head of Digital Oncology (MBBS, MD, DNB, FRCPath)', 'TMC-ACTREC, Mumbai', 'Head of Digital Oncology at TMC-ACTREC, Mumbai and developer of India’s "Imaging Biobank for Cancer".'),
(1, 'Dr. Shilpi Sahu', 'Head of Pathology & Chairperson - BOS (MBBS, MD)', 'MGM Medical College, Navi Mumbai', 'Head of Pathology at MGM Medical College, Navi Mumbai, and Chairperson of the Board of Studies.'),
(1, 'Dr. Sachin Kale', 'Professor of Pathology (MBBS, MD)', 'MGM Medical College, Navi Mumbai', 'Professor of Pathology at MGM Medical College with over two decades of academic and research leadership.'),
(1, 'Dr. Sagar Jaywantrao More', 'Consultant Histopathologist (MBBS, MD, FRCPath)', 'Sangli', 'Consultant Histopathologist, Sangli and UK Royal College Fellow specializing in complex lymphoma and hepatobiliary pathology.'),
(1, 'Dr. Rakhi Jagdale', 'Head of Pathology (MBBS, MD)', 'Shri Siddhivinayak Ganapati Cancer Hospital, Miraj', 'Head of Pathology at Shri Siddhivinayak Ganapati Cancer Hospital, Miraj, with a special interest in Uropathology and Head & Neck Pathology.'),
(1, 'Dr. Amruta Ashok Patil', 'Consultant Histopathologist (MBBS, MD, DNB, FRCPath)', 'Milton Keynes University Hospital, UK / Deesha Pathology Lab, Sangli', 'International speaker, Consultant at Milton Keynes University Hospital, UK and Consultant Histopathologist at Deesha Pathology Lab, Sangli, specializing in gastrointestinal oncopathology.'),
(1, 'Dr. Radhika Krishna Patil', 'Director (MBBS, MD, FISN-ANIO, PDCC)', 'Shri Balaji Kidney Care, Hyderabad', 'Director of Shri Balaji Kidney Care, Hyderabad and winner of 2024 Dr. APJ Abdul Kalam Health Excellence Award.'),
(1, 'Dr. Ashwini Mane Patil', 'Consultant Histopathologist (MBBS, MD Pathology)', 'Kolhapur Cancer Centre & Oncopathology Lab, Kolhapur', 'Consultant Histopathologist at Kolhapur cancer centre & Oncopathology lab, Kolhapur. Special interest in Breast & Gynae pathology.'),
(1, 'Dr. Kunal Sehgal', 'Consultant Haemato-Pathologist & Flow Cytometrist, Director (MBBS, MD)', 'Neuberg Sehgal Path Lab, Mumbai', 'Consultant Haemato-Pathologist and Flow Cytometrist. Director, Neuberg Sehgal path lab, Mumbai. Fellowship in hematopathology, UICC-ICCRETT Fellow.')
ON DUPLICATE KEY UPDATE
  designation = VALUES(designation),
  organization = VALUES(organization),
  bio = VALUES(bio);
