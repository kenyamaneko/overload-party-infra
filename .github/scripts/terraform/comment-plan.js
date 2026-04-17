// Terraform plan の結果を PR コメントとして投稿する。
// actions/github-script から `require` で読み込む想定。
// JS なのは github-script アクション自体が Node で octokit を呼ぶ仕組みのため。
// shell に寄せる場合は gh CLI + GH_TOKEN での書き換えが必要。
// 必要な環境変数: TF_ENV (対象環境名)

const fs = require('fs');
const path = require('path');

const MAX_BODY_CHARS = 60000;

module.exports = async ({ github, context }) => {
  const env = process.env.TF_ENV;
  if (!env) throw new Error('TF_ENV is required');

  const planPath = path.join('providers', env, 'plan.txt');
  const plan = fs.readFileSync(planPath, 'utf8');

  const body = [
    `### Terraform Plan — \`${env}\``,
    '```',
    plan.slice(-MAX_BODY_CHARS),
    '```',
  ].join('\n');

  await github.rest.issues.createComment({
    issue_number: context.issue.number,
    owner: context.repo.owner,
    repo: context.repo.repo,
    body,
  });
};
