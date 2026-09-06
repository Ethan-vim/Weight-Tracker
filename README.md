# Description
This project is a combination of a weight tracker and a calorie estimator for meals. 
It's meant to be simple-to-use, ADless, and free.

## Inspiration
This was inspired by the people that are trying to lose weight.  
Many people want a free and ad-less version of a weight tracker, so I built this app. 

## Calorie Estimator
In the `/Weight\ Tracker/Calorie\ Estimator/NutritionService.swift` there is a variable for the gemini api and another for the gemini model.  
The code is designed for gemini api from google ai studio, so changing it to another may not work.
The current api and model in the code is a free tier api from my google ai studio.  

## Core files
```
/Weight\ Tracker/Calorie\ Estimator/NutritionService.swift - Includes prompt and gemini api calling for nutrion feedback on meal
/Weight\ Tracker/Weight\ Graph/WeightGraphView.swift - Includes main view of weight graph on main page
/Weight\ Tracker/Weight\ Graph/WeightEntryDetailView.swift - Includes the detailed view page that opens up when clicking on weight entry dot
/Weight\ Tracker/Settings/SettingsPage.swift - Includes the entire settings page
```
