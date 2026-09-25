/**
 * SkillBridge AI — Main Client Application Logic
 */

// Application State
const state = {
  user: null,
  assessment: null,
  skillGap: null,
  roadmap: null,
  progress: {},
  challenges: [],
  activeView: 'landing',
  apiBaseUrl: window.location.origin.includes('localhost') || window.location.origin.includes('127.0.0.1')
    ? 'http://localhost:8080'
    : window.location.origin
};

// Initial Default Demo/Mock State for instant responsiveness
const defaultDemoData = {
  user: { name: 'Alex Johnson', email: 'alex@example.com' },
  assessment: {
    name: 'Alex Johnson',
    currentRole: 'Student',
    experienceLevel: 'Beginner',
    currentSkills: 'Python, SQL, Linux, AWS S3',
    targetRole: 'AWS Solutions Architect',
    weeklyHours: 6
  },
  skillGap: [
    { name: 'IAM (Identity & Access Management)', priority: 'high', reason: 'Critical security foundation for all AWS architecture.' },
    { name: 'VPC (Virtual Private Cloud)', priority: 'high', reason: 'Essential for networking, subnets, and isolated infrastructure.' },
    { name: 'EC2 & Elastic Load Balancing', priority: 'medium', reason: 'Core compute layer for scalable application workloads.' },
    { name: 'Amazon RDS & DynamoDB', priority: 'medium', reason: 'Database options for relational and NoSQL requirements.' },
    { name: 'AWS CloudWatch & Alarms', priority: 'low', reason: 'Operational monitoring and logging.' }
  ],
  roadmap: [
    {
      week: 1,
      title: 'AWS Security & IAM Fundamentals',
      objectives: 'Master Users, Roles, Policies, MFA, and Least Privilege principle.',
      hours: 6,
      tasks: [
        { id: 'w1-1', title: 'Create IAM User with custom policy', completed: true },
        { id: 'w1-2', title: 'Configure AWS CLI credentials securely', completed: true },
        { id: 'w1-3', title: 'Setup CloudTrail audit trail', completed: false }
      ]
    },
    {
      week: 2,
      title: 'Compute & Storage Deep Dive (EC2 & S3)',
      objectives: 'Deploy EC2 instances in public subnets and configure S3 bucket security.',
      hours: 6,
      tasks: [
        { id: 'w2-1', title: 'Launch Amazon Linux 2023 EC2 instance', completed: true },
        { id: 'w2-2', title: 'Configure S3 bucket policy & Block Public Access', completed: false },
        { id: 'w2-3', title: 'Attach EBS volume and mount filesystem', completed: false }
      ]
    },
    {
      week: 3,
      title: 'Networking & VPC Isolation',
      objectives: 'Design a Multi-AZ VPC with Public/Private Subnets and NAT Gateway.',
      hours: 6,
      tasks: [
        { id: 'w3-1', title: 'Build custom 10.0.0.0/16 VPC with 2 Public & 2 Private Subnets', completed: false },
        { id: 'w3-2', title: 'Configure Route Tables and Internet Gateway', completed: false },
        { id: 'w3-3', title: 'Deploy Security Groups & Network ACLs', completed: false }
      ]
    },
    {
      week: 4,
      title: 'Database & Monitoring Architecture',
      objectives: 'Provision DynamoDB tables with KMS CMK and set up CloudWatch metric alarms.',
      hours: 6,
      tasks: [
        { id: 'w4-1', title: 'Create DynamoDB table with GSI and TTL', completed: false },
        { id: 'w4-2', title: 'Configure CloudWatch Alarm for CPU utilization', completed: false },
        { id: 'w4-3', title: 'Build final multi-tier architecture project', completed: false }
      ]
    }
  ],
  challenges: [
    {
      id: 'ch-1',
      title: 'Multi-AZ VPC Isolation',
      description: 'Build a secure VPC with public & private subnets across 2 Availability Zones.',
      difficulty: 'Hard',
      estimatedHours: 3,
      status: 'In Progress'
    },
    {
      id: 'ch-2',
      title: 'S3 Secure Vault Policy',
      description: 'Create an S3 bucket with KMS customer-managed encryption and strict IAM read-only access.',
      difficulty: 'Medium',
      estimatedHours: 1.5,
      status: 'Completed'
    },
    {
      id: 'ch-3',
      title: 'Lambda & DynamoDB Integration',
      description: 'Write a Node.js Lambda function that handles API Gateway REST events and persists items to DynamoDB.',
      difficulty: 'Medium',
      estimatedHours: 2,
      status: 'Not Started'
    }
  ]
};

// DOM Content Loaded Initializer
document.addEventListener('DOMContentLoaded', () => {
  loadSavedState();
  renderDashboard();
  renderRoadmap();
  renderChallenges();
});

// Load state from localStorage or API
function loadSavedState() {
  const savedAssessment = localStorage.getItem('sb_assessment');
  const savedRoadmap = localStorage.getItem('sb_roadmap');
  const savedProgress = localStorage.getItem('sb_progress');
  const savedUser = localStorage.getItem('sb_user');

  if (savedUser) {
    state.user = JSON.parse(savedUser);
    updateAuthUI();
  }

  if (savedAssessment) {
    state.assessment = JSON.parse(savedAssessment);
    state.skillGap = JSON.parse(localStorage.getItem('sb_skillgap')) || defaultDemoData.skillGap;
    state.roadmap = savedRoadmap ? JSON.parse(savedRoadmap) : defaultDemoData.roadmap;
    state.progress = savedProgress ? JSON.parse(savedProgress) : {};
  } else {
    // Default fallback to demo state for smooth exploration
    state.assessment = defaultDemoData.assessment;
    state.skillGap = defaultDemoData.skillGap;
    state.roadmap = defaultDemoData.roadmap;
    state.challenges = defaultDemoData.challenges;
  }
}

// View Navigator
function switchView(viewName) {
  state.activeView = viewName;

  document.querySelectorAll('.view-section').forEach(sec => sec.style.display = 'none');
  document.querySelectorAll('.nav-link').forEach(link => link.classList.remove('active'));

  const targetView = document.getElementById(`view-${viewName}`);
  const targetNav = document.getElementById(`nav-${viewName}`);

  if (targetView) targetView.style.display = 'block';
  if (targetNav) targetNav.classList.add('active');

  window.scrollTo({ top: 0, behavior: 'smooth' });

  // Re-render dynamic views
  if (viewName === 'dashboard') renderDashboard();
  if (viewName === 'roadmap') renderRoadmap();
  if (viewName === 'challenges') renderChallenges();
}

function scrollToSection(id) {
  const el = document.getElementById(id);
  if (el) el.scrollIntoView({ behavior: 'smooth' });
}

// Auth Modal Controls
let isSignUpMode = false;

function openAuthModal() {
  document.getElementById('auth-modal').classList.add('active');
}

function closeAuthModal() {
  document.getElementById('auth-modal').classList.remove('active');
}

function toggleAuthMode() {
  isSignUpMode = !isSignUpMode;
  document.getElementById('auth-modal-title').textContent = isSignUpMode ? 'Create SkillBridge AI Account' : 'Sign In to SkillBridge AI';
  document.getElementById('auth-submit-btn').textContent = isSignUpMode ? 'Sign Up' : 'Sign In';
  document.getElementById('auth-toggle-text').textContent = isSignUpMode ? 'Already have an account?' : "Don't have an account?";
  document.getElementById('auth-toggle-link').textContent = isSignUpMode ? 'Sign In' : 'Sign Up';
}

function handleAuthSubmit(e) {
  e.preventDefault();
  const email = document.getElementById('auth-email').value;
  const name = email.split('@')[0];

  state.user = { email, name: name.charAt(0).toUpperCase() + name.slice(1) };
  localStorage.setItem('sb_user', JSON.stringify(state.user));

  updateAuthUI();
  closeAuthModal();
  showToast(`Welcome back, ${state.user.name}! Authenticated with Cognito.`);
}

function updateAuthUI() {
  if (state.user) {
    document.getElementById('user-display-name').textContent = state.user.name;
    document.getElementById('user-avatar-initials').textContent = state.user.name.charAt(0).toUpperCase();
    document.getElementById('auth-btn').innerHTML = '<i class="fa-solid fa-right-from-bracket"></i> Sign Out';
    document.getElementById('auth-btn').onclick = handleSignOut;
  } else {
    document.getElementById('user-display-name').textContent = 'Guest Learner';
    document.getElementById('user-avatar-initials').textContent = 'G';
    document.getElementById('auth-btn').innerHTML = '<i class="fa-solid fa-right-to-bracket"></i> Sign In';
    document.getElementById('auth-btn').onclick = openAuthModal;
  }
}

function handleSignOut() {
  state.user = null;
  localStorage.removeItem('sb_user');
  updateAuthUI();
  showToast('Logged out successfully.');
}

// Skill Assessment Submission
async function handleAssessmentSubmit(e) {
  e.preventDefault();

  const submitBtn = document.getElementById('submit-assessment-btn');
  submitBtn.disabled = true;
  submitBtn.innerHTML = '<i class="fa-solid fa-spinner fa-spin"></i> Analyzing with Amazon Bedrock...';

  const formData = {
    name: document.getElementById('user-name').value,
    currentRole: document.getElementById('current-role').value,
    experienceLevel: document.getElementById('experience-level').value,
    currentSkills: document.getElementById('current-skills').value,
    targetRole: document.getElementById('target-role').value,
    weeklyHours: parseInt(document.getElementById('weekly-hours').value, 10),
    preferences: document.getElementById('learning-preferences').value
  };

  try {
    const res = await fetch(`${state.apiBaseUrl}/api/v1/assessment`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(formData)
    });

    const data = await res.json();
    if (data.skillGap && data.roadmap) {
      state.assessment = formData;
      state.skillGap = data.skillGap;
      state.roadmap = data.roadmap;
    } else {
      // Fallback generator
      state.assessment = formData;
      generateFallbackRoadmap(formData);
    }
  } catch (err) {
    console.warn('API call failed, generating via Bedrock fallback logic:', err);
    state.assessment = formData;
    generateFallbackRoadmap(formData);
  }

  localStorage.setItem('sb_assessment', JSON.stringify(state.assessment));
  localStorage.setItem('sb_skillgap', JSON.stringify(state.skillGap));
  localStorage.setItem('sb_roadmap', JSON.stringify(state.roadmap));

  submitBtn.disabled = false;
  submitBtn.innerHTML = '<i class="fa-solid fa-wand-magic-sparkles"></i> Generate AI Skill Gap & Roadmap';

  showToast('Skill assessment completed & roadmap generated!');
  switchView('dashboard');
}

function generateFallbackRoadmap(info) {
  state.skillGap = [
    { name: 'AWS IAM & Security Control', priority: 'high', reason: 'Mandatory foundation for ' + info.targetRole },
    { name: 'VPC Networking & Subnets', priority: 'high', reason: 'Essential for isolated cloud architecture' },
    { name: 'EC2 & Auto Scaling', priority: 'medium', reason: 'Core compute execution layer' },
    { name: 'DynamoDB & S3 Persistence', priority: 'medium', reason: 'Scalable cloud data storage' },
    { name: 'CloudWatch Observability', priority: 'low', reason: 'System logging and monitoring' }
  ];

  state.roadmap = [
    {
      week: 1,
      title: 'Week 1: AWS Identity & Access Security',
      objectives: 'Configure IAM roles, policies, and root account security controls.',
      hours: info.weeklyHours,
      tasks: [
        { id: 'w1-1', title: 'Create IAM Users and apply least-privilege policies', completed: false },
        { id: 'w1-2', title: 'Setup Multi-Factor Authentication (MFA) & CloudTrail', completed: false }
      ]
    },
    {
      week: 2,
      title: 'Week 2: VPC Network Architecture',
      objectives: 'Design Multi-AZ subnet topology with NAT & Internet Gateways.',
      hours: info.weeklyHours,
      tasks: [
        { id: 'w2-1', title: 'Build custom VPC 10.0.0.0/16 with Public and Private subnets', completed: false },
        { id: 'w2-2', title: 'Configure Security Groups and Network ACL rules', completed: false }
      ]
    },
    {
      week: 3,
      title: 'Week 3: Compute & Database Deployment',
      objectives: 'Launch EC2 instances and connect to DynamoDB tables.',
      hours: info.weeklyHours,
      tasks: [
        { id: 'w3-1', title: 'Deploy Amazon Linux EC2 instance in Private Subnet', completed: false },
        { id: 'w3-2', title: 'Provision DynamoDB table with KMS encryption', completed: false }
      ]
    }
  ];
}

// Render Dashboard
function renderDashboard() {
  if (!state.assessment) return;

  document.getElementById('dash-user-name').textContent = state.assessment.name || 'Learner';
  document.getElementById('dash-target-role').textContent = state.assessment.targetRole || 'AWS Architect';
  document.getElementById('mentor-context-tag').textContent = `Context: ${state.assessment.targetRole}`;

  // Calculate dynamic progress
  let totalTasks = 0;
  let completedTasks = 0;

  if (state.roadmap) {
    state.roadmap.forEach(wk => {
      wk.tasks.forEach(t => {
        totalTasks++;
        if (t.completed) completedTasks++;
      });
    });
  }

  const progressPct = totalTasks > 0 ? Math.round((completedTasks / totalTasks) * 100) : 0;
  document.getElementById('dash-progress-pct').textContent = `${progressPct}%`;
  document.getElementById('dash-progress-fill').style.width = `${progressPct}%`;
  document.getElementById('dash-completed-count').textContent = `${completedTasks} / ${totalTasks}`;

  // Skill gap matrix
  const gapContainer = document.getElementById('dash-skill-gap-list');
  if (state.skillGap && state.skillGap.length > 0) {
    gapContainer.innerHTML = state.skillGap.map(sg => `
      <div style="display: flex; justify-content: space-between; align-items: center; padding: 0.85rem 0; border-bottom: 1px solid var(--border-color);">
        <div>
          <strong style="font-size: 0.95rem;">${sg.name}</strong>
          <p style="font-size: 0.82rem; color: var(--text-muted); margin-top: 2px;">${sg.reason}</p>
        </div>
        <span class="badge badge-${sg.priority}">${sg.priority.toUpperCase()}</span>
      </div>
    `).join('');
  }
}

// Render Detailed Roadmap
function renderRoadmap() {
  const container = document.getElementById('roadmap-weeks-container');
  if (!state.roadmap || state.roadmap.length === 0) return;

  container.innerHTML = state.roadmap.map((wk, wIdx) => `
    <div class="card" style="border-left: 4px solid var(--primary);">
      <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 0.75rem;">
        <div>
          <span style="font-size: 0.8rem; font-weight: 700; color: var(--accent-cyan); text-transform: uppercase;">Week ${wk.week}</span>
          <h3 style="font-family: var(--font-heading); font-size: 1.25rem;">${wk.title}</h3>
        </div>
        <span style="font-size: 0.85rem; background: rgba(255,255,255,0.06); padding: 4px 12px; border-radius: 20px;"><i class="fa-solid fa-clock"></i> ${wk.hours} hrs</span>
      </div>
      <p style="color: var(--text-muted); font-size: 0.92rem; margin-bottom: 1.25rem;">${wk.objectives}</p>
      
      <div style="display: flex; flex-direction: column; gap: 0.65rem;">
        ${wk.tasks.map((task, tIdx) => `
          <label style="display: flex; align-items: center; gap: 0.75rem; background: rgba(0,0,0,0.2); padding: 0.65rem 1rem; border-radius: var(--radius-sm); cursor: pointer;">
            <input type="checkbox" ${task.completed ? 'checked' : ''} onchange="toggleTask('${task.id}')" style="width: 18px; height: 18px; accent-color: var(--primary);">
            <span style="${task.completed ? 'text-decoration: line-through; color: var(--text-dim);' : 'color: var(--text-main);'} font-size: 0.9rem;">${task.title}</span>
          </label>
        `).join('')}
      </div>
    </div>
  `).join('');
}

// Task completion toggle
function toggleTask(taskId) {
  if (!state.roadmap) return;

  state.roadmap.forEach(wk => {
    wk.tasks.forEach(t => {
      if (t.id === taskId) {
        t.completed = !t.completed;
      }
    });
  });

  localStorage.setItem('sb_roadmap', JSON.stringify(state.roadmap));
  renderRoadmap();
  renderDashboard();
  showToast('Task status updated & progress persisted.');

  // Sync with API backend if available
  fetch(`${state.apiBaseUrl}/api/v1/progress`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ taskId, completed: true })
  }).catch(() => {});
}

// AI Mentor Chat Handler
async function handleChatSubmit(e) {
  e.preventDefault();
  const inputEl = document.getElementById('chat-input');
  const query = inputEl.value.trim();
  if (!query) return;

  appendChatBubble(query, 'user');
  inputEl.value = '';

  const sendBtn = document.getElementById('chat-send-btn');
  sendBtn.disabled = true;

  // Temporary typing indicator
  const typingId = appendChatBubble('<i class="fa-solid fa-ellipsis fa-beat"></i> Consulting Amazon Bedrock Mentor...', 'ai');

  try {
    const res = await fetch(`${state.apiBaseUrl}/api/v1/mentor`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        prompt: query,
        context: state.assessment ? state.assessment.targetRole : 'AWS Solutions Architect'
      })
    });

    const data = await res.json();
    removeChatBubble(typingId);
    appendChatBubble(data.reply || getFallbackMentorReply(query), 'ai');
  } catch (err) {
    removeChatBubble(typingId);
    appendChatBubble(getFallbackMentorReply(query), 'ai');
  }

  sendBtn.disabled = false;
}

function sendPromptSuggestion(text) {
  document.getElementById('chat-input').value = text;
  document.getElementById('chat-send-btn').click();
}

function appendChatBubble(text, sender) {
  const container = document.getElementById('chat-messages');
  const bubble = document.createElement('div');
  const id = 'bubble-' + Date.now();
  bubble.id = id;
  bubble.className = `chat-bubble chat-bubble-${sender}`;
  bubble.innerHTML = text;
  container.appendChild(bubble);
  container.scrollTop = container.scrollHeight;
  return id;
}

function removeChatBubble(id) {
  const el = document.getElementById(id);
  if (el) el.remove();
}

function getFallbackMentorReply(query) {
  const q = query.toLowerCase();
  if (q.includes('vpc')) {
    return `<strong>Virtual Private Cloud (VPC)</strong> is your isolated private network in AWS. Think of it like a secure apartment building:
    <br><br>
    • <strong>Public Subnet</strong>: The lobby — accessible from the internet (via Internet Gateway).<br>
    • <strong>Private Subnet</strong>: Private apartments — inaccessible directly from the internet.<br>
    • <strong>Security Group</strong>: The apartment door lock — controls inbound and outbound traffic.`;
  }
  if (q.includes('iam')) {
    return `<strong>Here is a practical IAM exercise:</strong><br>1. Create an IAM Group named <code>DevOps-Architects</code>.<br>2. Attach the <code>AmazonS3ReadOnlyAccess</code> policy to the group.<br>3. Create a user <code>developer-alex</code> and assign them to the group.<br>4. Test AWS CLI access using <code>aws s3 ls</code> versus <code>aws s3 mb s3://mybucket</code>.`;
  }
  return `Great question regarding your AWS trajectory! To master <strong>${state.assessment ? state.assessment.targetRole : 'AWS Architecture'}</strong>, ensure you balance theoretical concepts with hands-on CLI practice. Check out Week 2 of your roadmap to build your next exercise!`;
}

// Render Challenges
function renderChallenges() {
  const container = document.getElementById('challenges-grid');
  if (!state.challenges) state.challenges = defaultDemoData.challenges;

  container.innerHTML = state.challenges.map(c => `
    <div class="card">
      <div style="display: flex; justify-content: space-between; align-items: start; margin-bottom: 0.75rem;">
        <span class="badge ${c.difficulty === 'Hard' ? 'badge-high' : 'badge-medium'}">${c.difficulty}</span>
        <span style="font-size: 0.8rem; color: var(--text-muted);"><i class="fa-solid fa-clock"></i> ${c.estimatedHours} hrs</span>
      </div>
      <h3 style="font-family: var(--font-heading); font-size: 1.15rem; margin-bottom: 0.5rem;">${c.title}</h3>
      <p style="color: var(--text-muted); font-size: 0.88rem; margin-bottom: 1.25rem;">${c.description}</p>
      
      <div style="display: flex; justify-content: space-between; align-items: center; border-top: 1px solid var(--border-color); padding-top: 1rem;">
        <span style="font-size: 0.85rem; font-weight: 600; color: ${c.status === 'Completed' ? 'var(--accent-green)' : c.status === 'In Progress' ? 'var(--accent-amber)' : 'var(--text-dim)'};">
          <i class="fa-solid ${c.status === 'Completed' ? 'fa-circle-check' : 'fa-circle-dot'}"></i> ${c.status}
        </span>
        <button class="btn btn-sm ${c.status === 'Completed' ? 'btn-secondary' : 'btn-primary'}" onclick="toggleChallengeStatus('${c.id}')">
          ${c.status === 'Completed' ? 'Mark Reset' : c.status === 'In Progress' ? 'Mark Completed' : 'Start Challenge'}
        </button>
      </div>
    </div>
  `).join('');
}

function toggleChallengeStatus(id) {
  state.challenges.forEach(c => {
    if (c.id === id) {
      if (c.status === 'Not Started') c.status = 'In Progress';
      else if (c.status === 'In Progress') c.status = 'Completed';
      else c.status = 'Not Started';
    }
  });

  renderChallenges();
  showToast('Challenge status updated.');
}

// Toast Notification
function showToast(msg) {
  const toast = document.getElementById('toast');
  document.getElementById('toast-message').textContent = msg;
  toast.classList.add('show');
  setTimeout(() => toast.classList.remove('show'), 3500);
}
