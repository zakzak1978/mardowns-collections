#### Entering the container
```
kubectl exec -i -t -n feature-securityfix sdp-import-api-5f7cd4fd7f-f7r9q -c sdp-import-api -- sh -c "clear; (bash || ash || sh)"
```

#### Getting previous container's crashed logs
```
kubectl logs sdp-import-api-5f7cd4fd7f-f7r9q --previous -n feature-securityfix
```
#### Describing pod to get more information
```
kubectl describe pod sdp-import-api-5f7cd4fd7f-f7r9q -n feature-securityfix

```

