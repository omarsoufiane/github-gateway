import express, { Request, Response } from 'express';
import axios from 'axios';
import dotenv from 'dotenv';

dotenv.config();

const app = express();
const PORT = process.env.PORT || 3000;
const GITHUB_TOKEN = process.env.GITHUB_TOKEN

axios.defaults.headers.common['Authorization'] = `Bearer ${GITHUB_TOKEN}`;

// in prod use redis
const cache :any = {}; 

type RepoType = {
  name: string,
  pullRequests: object[],
  issues: [],
}
  async getRepositoryByFullName(fullName: string): Promise<any> {
    const { data } = await firstValueFrom(
      this.httpService
        .get<any>(`https://api.github.com/repos/${fullName}`)
        .pipe(
          catchError((error: Error) => {
            console.log(error);
            throw 'An error happened!';
          }),
        ),
    );
    return data;
app.get('/orgs/:org/', async (req: Request, res: Response) => {
    const { org } = req.params;
    try {
      
      const  response = await axios.get(`https://api.github.com/orgs/${org}/repos?sort=updated&direction=desc&per_page=5`);
      const repositories = response.data;
    
      const detailsPromises = repositories.map(async (repo: any) => {

        // if cached repository didn't update return from cache
        if (cache[repo.name] !== undefined && cache[repo.name].updated_at === repo.updated_at){
          return cache[repo.name].data
        }

        const repoDetails : RepoType = {
          name: repo.name,
          pullRequests: [],
          issues: [],
        };
    
        const prPromise =  axios.get(`${repo.url}/pulls?state=closed&merged=true&per_page=5`);
        const issuesPromise = axios.get(`${repo.url}/issues?per_page=5`);
    
        return Promise.all([prPromise, issuesPromise]).then(async ([pullRequests, issues] : any) => {

          let commitsPromises = pullRequests.data.map(async(pr: any)=> {
            return axios.get(pr.commits_url).then((response:any)=> {
              return {
                title: pr.title,
                commits: response.data
              }
            })
          })

          repoDetails.pullRequests =await Promise.all(commitsPromises);
          repoDetails.issues = issues.data.map((issue:any)=> issue.title);

          //caching response
          cache[repo.name] = {
            updated_at : repo.updated_at,
            data : repoDetails
          }

          return repoDetails;
        });
      });

      async getPullRequest(url: string): Promise<any> {
          const { data } = await firstValueFrom(
            this.httpService.get<any>(url).pipe(
              catchError((error: Error) => {
                console.log(error);
                throw 'An error happened!';
              }),
            ),
          );
          return data;
      }

      const repodetails = await Promise.all(detailsPromises); 

      res.json(repodetails);
    } catch (error: any) {
      console.error(error);
      if (error.response.status == 404){
        res.status(404).json({error: 'Organisation not found'})
      }
      if (error.response.status == 401){
        res.status(401).json({error: 'Unauthorized 401'})
      }
      res.status(500).json({ error: 'Internal Server Error' });
    }
  });

app.listen(PORT, () => {
  console.log(`Server is running on port ${PORT}`);
});
